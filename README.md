# How to place storage order through XCM from Astar contract to Crust
This is a solidity contract sample to demonstrate how to call the place storage order from Astar contract to Crust.

#### Here are two major steps
1.  [Transfer some SDN token from the Astar to the Crust Shadow as the xcm transact and storage order fee.](https://github.com/crustio/xcmp-evm-sc/blob/e6ac3f27be48a458becb17781148fa744d304a3d/contracts/CrossStorageOrder.sol#L142-L148)
2.  [Send cross chain storage order from the Astar to the Crust Shadow.](https://github.com/crustio/xcmp-evm-sc/blob/e6ac3f27be48a458becb17781148fa744d304a3d/contracts/CrossStorageOrder.sol#L151-L162)

#### Transfer SDN token from the Astar to the Crust Shadow
Please follow the [astar's wiki](https://docs.astar.network/docs/xcm/building-with-xcm/xc-reserve-transfer) to achieve the goal. The `recipient_account_id` should be the corresponding polkadot address of the smart contract address. The reason that we need this corresponding address and the calculation process would be explained in the later section.

#### Send cross chain storage order from the Astar to the Crust Shadow
It relys on the [xcm.transact_message](https://docs.astar.network/docs/xcm/building-with-xcm/xc-remote-transact) to achieve this goal. In this sample, it shows how to [build the call data](https://github.com/crustio/xcmp-evm-sc/blob/e6ac3f27be48a458becb17781148fa744d304a3d/contracts/CrossStorageOrder.sol#L94-L106). Other part can be checked in [Astar's wiki](https://docs.astar.network/docs/xcm/building-with-xcm/xc-remote-transact) as well.

#### Correponding address calculation process
To execute the cross chain storage order, the xcm transaction and the storage order fees should be paid by the smart contract on the crust shadow side. Currently the address convertion process is ```Shiden's EVM address => Shiden's sr25519 address => Crust's sr25519 address```. The sc need the crust's sr25519 address as an input parameter. It's decided by both shiden and crust. Meanwhile, the smart contract's address won't change after the deployment. It's suitable to calculate the corresponding address offline and set it into the smart contract.

There are two steps.
1. Shiden's EVM address => Shiden's sr25519 address: There is an utily page to help do it. https://hoonsubin.github.io/evm-substrate-address-converter/. It's provided by Astar's engineer. The logic can be checked in this [codesnippet](https://github.com/AstarNetwork/frontier/blob/1e6ea2f2958c6a264db7495d86feeae8de4d9354/frame/evm/src/lib.rs#L612-L621)
2. Shiden's sr25519 address => Crust's sr25519 address: It's same and no converting here. However, the evm need the AccountId as the input parameter instead of the ss58 format address. Please use `subkey` or [subscan's tool](https://crust.subscan.io/tools/format_transform) to get the account id(Public Key).

#### Example
Extrinsic on the shiden's side.
https://shiden.subscan.io/extrinsic/2903463-2

Recieved XCM message on the crust shadow's side
https://shadow.subscan.io/extrinsic/1851184-1?event=1851184-6