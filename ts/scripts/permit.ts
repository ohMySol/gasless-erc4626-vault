import {ethers, TypedDataDomain} from "ethers";
import dotenv from 'dotenv';
import fs from 'fs';

dotenv.config({path:'../.env'});

const abi = JSON.parse(fs.readFileSync("../out/MyToken.sol/MyToken.abi.json", "utf8"));

function getTimestampInSeconds() {
    return Math.floor(Date.now() / 1000);
}

/**
 * This script is used to test that the permission for spender signed off chain is working correctly.
 */
async function main() {
    // Get Provider instance
    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);

    // Get chain ID
    const chainId = (await provider.getNetwork()).chainId;

    // Create a signer instance with token owner
    const tokenOwner = new ethers.Wallet(process.env.PRIVATE_KEY_DEPLOYER as string, provider);
    
    // Create a receiver instance with token receiver
    const tokenReceiver = new ethers.Wallet(process.env.PRIVATE_KEY_ACCOUNT_2 as string, provider);
    
    // Get MyToken contract instance
    const myToken = new ethers.Contract("0xd4F4b53a98eC7D93503CebA941FEDbd10Ee26f95", abi, provider);

    // Check account balances | Shoudl be 0 both accounts
    console.log(`Staring token owner balance: ${await myToken.balanceOf(tokenOwner.address)}`)
    console.log(`Staring token receiver balance: ${await myToken.balanceOf(tokenReceiver.address)}`)

    // Set token value, deadline and nonce of token owner
    const value = ethers.parseEther("100"); // Permit receiver to spend 100 tokens
    const deadline = getTimestampInSeconds() + 4200;
    const nonce = await myToken.nonces(tokenOwner.address);

    // Set the domain parameters
    const domain = {
        name: await myToken.name(),
        version: "1",
        chainId: chainId,
        verifyingContract: await myToken.getAddress()
    };

    // Set the Permit type parameters
    const types = {
        Permit: [{
            name: "owner",
            type: "address"
          },
          {
            name: "spender",
            type: "address"
          },
          {
            name: "value",
            type: "uint256"
          },
          {
            name: "nonce",
            type: "uint256"
          },
          {
            name: "deadline",
            type: "uint256"
          },
        ],
    };

    // Set the Permit type values 
    const values = {
        owner: tokenOwner.address,
        spender: tokenReceiver.address,
        value: value,
        nonce: nonce,
        deadline: deadline,
    }

    // Sign the permit
    const signature = await tokenOwner.signTypedData(domain, types, values);
    // Split the signature into its components: v, r and s
    const splitted = ethers.Signature.from(signature);
    // Verify the Permit type data with the signature
    const recovered = ethers.verifyTypedData(domain, types, values, signature);

    // Permit the `tokenReceiver` address to spend tokens on behalf of the `tokenOwner`
    let tx = await myToken.connect(tokenReceiver).getFunction("permit")(
      tokenOwner.address,
      tokenReceiver.address,
      value,
      deadline,
      splitted.v, // v
      splitted.r, // r
      splitted.s, // s
    );
    await tx.wait(2);

    // Check that token receiver now has allowance to spend 100 tokens
    console.log(`Token receiver allowance: ${await myToken.allowance(tokenOwner.address, tokenReceiver.address)}`);

    // Transfer tokens from `tokenOwner` to `tokenReceiver`
    let tx2 = await myToken.connect(tokenReceiver).getFunction("transferFrom")(
        tokenOwner.address, 
        tokenReceiver.address, 
        value
    )
    await tx2.wait(2);

    // Get balances of both accounts
    console.log(`Final token owner balance: ${await myToken.balanceOf(tokenOwner.address)}`);
    console.log(`Final token receiver balance: ${await myToken.balanceOf(tokenReceiver.address)}`);
}

main().catch((error) => {
    console.log(error);
    process.exit(1);
})