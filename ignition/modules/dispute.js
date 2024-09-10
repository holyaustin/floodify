// deploy.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("NFTFactoryModule", (m) => {
  const eCourt = m.contract("eCourt");

  return {
    eCourt,
  };
});
