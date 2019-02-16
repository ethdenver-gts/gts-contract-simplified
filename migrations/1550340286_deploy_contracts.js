var GlobalTradeSystem = artifacts.require("./GlobalTradeSystem.sol");

module.exports = function(deployer) {
  deployer.deploy(GlobalTradeSystem);
};
