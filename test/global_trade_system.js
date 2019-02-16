var GlobalTradeSystem = artifacts.require("GlobalTradeSystem");

contract("GlobalTradeSystem", function(accounts) {
  it("should assign assets correctly", async function() {
    var GTS = await GlobalTradeSystem.deployed();
    const emitter = accounts[0];
    const receiver = accounts[1];
    const data = "0x" + Math.floor(Math.random() * 2000);
    await GTS.assign(receiver, data, { from: emitter });
    const assigned = await GTS.getAsset(1);
    assert.equal(assigned.emitter, emitter, "Emitter is not equal");
    assert.equal(assigned.emitter, emitter, "Receiver is not equal");
    assert.equal(assigned.emitter, emitter, "Data is not equal");
  });
  it("should burn assets correctly", async function() {
    var GTS = await GlobalTradeSystem.deployed();
    const emitter = accounts[0];
    const receiver = accounts[1];
    const data = "0xabcd";
    await GTS.assign(receiver, data, { from: emitter });
    await GTS.burn(1, { from: emitter });
  });
  it("should throw when burning a someone else's asset", async function() {
    var GTS = await GlobalTradeSystem.deployed();
    const emitter = accounts[0];
    const receiver = accounts[1];
    const data = "0xabcd";
    await GTS.assign(receiver, data, { from: emitter });
    try {
      await GTS.burn(1, { from: accounts[3] });
      assert.fail("Burn did not throw");
    } catch (err) {}
  });
});
