import { Clarinet, Tx, Chain, Account, types } from "@stacks/clarity";

Clarinet.test({
  name: "Create and Pledge Project",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const creator = accounts.get("deployer")!;
    const backer = accounts.get("wallet_1")!;
    
    const createTx = chain.mineBlock([
      Tx.contractCall("crowdfunding", "create-project", [
        types.uint(1),
        types.uint(1000),
        types.uint(100),
        types.list([types.uint(50), types.uint(100)])
      ], creator.address)
    ]);
    createTx.receipts[0].result.expectOk().expectUint(1);

    const pledgeTx = chain.mineBlock([
      Tx.contractCall("crowdfunding", "pledge", [
        types.uint(1),
        types.uint(500)
      ], backer.address)
    ]);
    pledgeTx.receipts[0].result.expectOk().expectUint(500);
  }
});
