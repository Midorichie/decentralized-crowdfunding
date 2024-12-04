import { Clarinet, Tx, Chain, Account, types } from "@stacks/clarity";

Clarinet.test({
  name: "Project creation validations",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const creator = accounts.get("deployer")!;
    
    // Test invalid funding goal
    let block = chain.mineBlock([
      Tx.contractCall("crowdfunding", "create-project", [
        types.uint(1),
        types.uint(0),
        types.uint(100),
        types.list([types.uint(50), types.uint(100)])
      ], creator.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(101);

    // Test invalid deadline
    block = chain.mineBlock([
      Tx.contractCall("crowdfunding", "create-project", [
        types.uint(2),
        types.uint(1000),
        types.uint(0),
        types.list([types.uint(50), types.uint(100)])
      ], creator.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(102);

    // Test duplicate project ID
    block = chain.mineBlock([
      Tx.contractCall("crowdfunding", "create-project", [
        types.uint(3),
        types.uint(1000),
        types.uint(100),
        types.list([types.uint(50), types.uint(100)])
      ], creator.address)
    ]);
    block.receipts[0].result.expectOk().expectUint(3);

    block = chain.mineBlock([
      Tx.contractCall("crowdfunding", "create-project", [
        types.uint(3),
        types.uint(2000),
        types.uint(200),
        types.list([types.uint(50), types.uint(100)])
      ], creator.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(100);
  },
});

Clarinet.test({
  name: "Pledge validations",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const creator = accounts.get("deployer")!;
    const backer = accounts.get("wallet_1")!;
    
    // Create test project
    let block = chain.mineBlock([
      Tx.contractCall("crowdfunding", "create-project", [
        types.uint(1),
        types.uint(1000),
        types.uint(100),
        types.list([types.uint(50), types.uint(100)])
      ], creator.address)
    ]);
    block.receipts[0].result.expectOk().expectUint(1);

    // Test pledge to non-existent project
    block = chain.mineBlock([
      Tx.contractCall("crowdfunding", "pledge", [
        types.uint(999),
        types.uint(500)
      ], backer.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(200);

    // Test zero amount pledge
    block = chain.mineBlock([
      Tx.contractCall("crowdfunding", "pledge", [
        types.uint(1),
        types.uint(0)
      ], backer.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(201);

    // Test pledge exceeding funding goal
    block = chain.mineBlock([
      Tx.contractCall("crowdfunding", "pledge", [
        types.uint(1),
        types.uint(1001)
      ], backer.address)
    ]);
    block.receipts[0].result.expectErr().expectUint(203);

    // Test successful pledge
    block = chain.mineBlock([
      Tx.contractCall("crowdfunding", "pledge", [
        types.uint(1),
        types.uint(500)
      ], backer.address)
    ]);
    block.receipts[0].result.expectOk().expectUint(500);
  },
});
