async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contract with the account:", deployer.address);
  
    const balance = await deployer.getBalance();
    console.log("Account balance:", ethers.utils.formatEther(balance.toString()));
  
    const CustomBetting = await ethers.getContractFactory("CustomBetting");
    const customBetting = await CustomBetting.deploy();
  
    console.log("Waiting for deployment...");
    await customBetting.deployed();
  
    console.log("CustomBetting contract deployed at:", customBetting.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
  