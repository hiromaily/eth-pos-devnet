# How to create devnet or localnet for another consensus client

## 挙動の説明

1. `go-ethereum` で proof-of-work development node を genesis config によって初期化する
2. `Prysm beacon chain` で proof-of-stake development node を genesis config によって初期化する
3. `go-ethereum`で mining を開始し、並行して Prysm の proof-of-stake node を走らせる
4. `go-ethereum` node の mining difficulty が一度 `50`に達したら, その node は Prysm にブロックのコンセンサスを駆動させることによって、proof-of-stake mode に switch する

## Prysm の設定

- [config.yml](./consensus/config.yml)は変更することも可能。例えば、`BELLATRIX_FORK_EPOCH`によって各 slot 間隔が 4 秒になっているため、処理が早く進む。
- [Prysm Client Interoperability Guide](https://github.com/prysmaticlabs/prysm/blob/develop/INTEROP.md)
  - この config は、prysm で定義している`interop` network (testnet)が base になっている
- TODO: lodestar を使う場合、そっくりこの設定を使う必要があるわけではなく、必要な設定が見極められればよい

## go-ethreum の設定

- private key を設定する必要があり、マイニングによってチェーンを genesis から PoS モードに到達するまで進めるために利用される
- go-ethereum の genesis.json によって、特定のアカウントに ETH 残高をシードし、アドレス `0x4242424242424242424242` に`validator deposit contract`を deploy する
  - これは、新しいバリデータが 32 ETH を入金して、ステーク証明チェーンに参加するために使用されるコントラクト
  - go-ethereum を実行しているアカウント、`0x123463a4b065722e99115d6c222f267d9cabb524`は、localnet でトランザクションを提出するために使用できる ETH 残高を持つことになる。
- Prysm ビーコンノードとバリデータクライアントを実行する必要があるが、Prysm は`genesis state`を必要とする。
  - `genesis state`とは、基本的にはバリデータの初期セットを示すデータのこと。
  - これは、docker-compose の`create-beacon-chain-genesis`によって生成される。
- prysm の peer を追加する方法も別途記載している

## 状況整理

- `geth`の設定はそのまま流用できる
- 現在の example は`prysm`を使っている。厳密には[prysm の interop](https://github.com/prysmaticlabs/prysm/blob/develop/INTEROP.md)
- 用意された [genesis config](../consensus/config.yml) を使ってその他の node にどうやって適用するか、が焦点になる
- docker-compose 内の、`create-beacon-chain-genesis`サービスがどのような挙動をするのか確認
  - この service を起動することによって、config から、`genesis.ssz`が生成される
- docker-compose 内の、`beacon-chain`サービスで起動している prysm の beacon node の起動 option を Lodestar の node にも適用する必要がある。

```
  beacon-chain:
    image: "gcr.io/prysmaticlabs/prysm/beacon-chain:latest"
    command:
      - --datadir=/consensus/beacondata
      # No peers to sync with in this testnet, so setting to 0
      - --min-sync-peers=0
      - --interop-genesis-state=/consensus/genesis.ssz
      - --interop-eth1data-votes
      - --bootstrap-node=
      # The chain configuration file used for setting up Prysm
      - --chain-config-file=/consensus/config.yml
      # We specify the chain id used by our execution client
      - --chain-id=32382
      - --rpc-host=0.0.0.0
      - --grpc-gateway-host=0.0.0.0
      - --execution-endpoint=http://geth:8551
      - --chain-id=32382
      - --accept-terms-of-use
      - --jwt-secret=/execution/jwtsecret
      - --suggested-fee-recipient=0x123463a4b065722e99115d6c222f267d9cabb524
```

| Prysm                     | Lodestar                                                                                 | 説明                                                                                             |
| ------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| --datadir                 | --dataDir                                                                                |                                                                                                  |
| --min-sync-peers          | --targetPeers ??                                                                         | 0 を設定する                                                                                     |
| --interop-genesis-state   | x `dev`モードではできない                                                                | /consensus/genesis.ssz を指定するもの                                                            |
| --interop-eth1data-votes  | x ??                                                                                     | 提案者によってブロックに入れられた eth1 プルーフ オブ ワーク チェーン データのモックを可能にする |
| --bootstrap-node          | --bootnodes ??                                                                           | 空を設定する。default は空                                                                       |
| --chain-config-file       | configFile というものがあったが、deprecated になっている。paramsFileがこれに該当するはず | /consensus/config.yml を指定するもの                                                             |
| --chain-id                | x                                                                                        | 32382 を設定する。設定できないので、コードに手を入れる必要がある？                               |
| --rpc-host                | --rest.address (--rest も必要)                                                           | 0.0.0.0 を設定する                                                                               |
| --grpc-gateway-host       | x                                                                                        | 不要                                                                                             |
| --execution-endpoint      | --execution.urls                                                                         |                                                                                                  |
| --accept-terms-of-use     | x                                                                                        | 不要                                                                                             |
| --jwt-secret              | --jwt-secret                                                                             |                                                                                                  |
| --suggested-fee-recipient | --suggestedFeeRecipient                                                                  |                                                                                                  |

- 補足
  - [interop-eth1data-votes](https://github.com/prysmaticlabs/prysm/blob/develop/cmd/beacon-chain/flags/interop.go#L15-L19)
- TODO: 場合によっては、lodestar を fork してハードコードされている箇所の修正が必要になるかもしれない

## Lodestar

### Local testnet について

- [Local testnet](https://chainsafe.github.io/lodestar/usage/local/)
- `dev`サブコマンドをつけて起動することで、beacon node と validator が立ち上がる
- 今回`dev`モードで起動する必要があるのか？`beacon`モードでもいいのかもしれない。

### `dev`モードの内部的な挙動について

- [Github lodestar cli](https://github.com/ChainSafe/lodestar/tree/unstable/packages/cli)
- `process.env.LODESTAR_PRESET`に`minimal`がセットされる
- `process.env.LODESTAR_NETWORK`に`dev`がセットされる。しかし、`LODESTAR_NETWORK`が使われている様子はない？
- `cmds/dev/handler.ts`の`devHandler()`内の処理
  - `network`が`dev`に設定される
  - `genesisStateFile`を option で指定しても skip されてしまう。
  - `initDevState()`によって、state が作られ、`genesis.ssz`が内部的に作られる
  - 現在の挙動で`dev`モードを使うことは難しい
  - 全体的に、`dev`の設定が望ましいが、genesisState が設定できない問題さえクリアできれば問題解決できるかもしれない

### `beacon`モードの内部的な挙動について

- `cmds/beacon/handler.ts`の`beaconHandler()`内の処理
  - beaconHandlerInit() ... argsからconfig,option,networkなどを返す
    - getBeaconConfigFromArgs() ... `IChainConfig`を返す
      - `IChainConfig`について
        - [`packages/config/src/chainConfig/types.ts`](https://github.com/ChainSafe/lodestar/blob/unstable/packages/config/src/chainConfig/types.ts)に定義されている
        - これは、eth-pos-devnetの[consensus/config.yml](https://github.com/rauljordan/eth-pos-devnet/blob/master/consensus/config.yml)とほぼ同じだが、`SLOTS_PER_EPOCH`が、このtypescriptで書かれた`IChainConfig`に定義されていない。
      - `createIChainForkConfig(getBeaconParamsFromArgs(args));`のresponseがconfigの実態となる
        - getBeaconParamsFromArgs()
          - `args.network`, `args.paramsFile`が使われる
          - getBeaconParams()
            - `getNetworkBeaconParams(network)`によって、`networkParams`を設定
              - `getNetworkData(network).chainConfig`によって、network種別に応じて定義済みの設定情報を返す(cli package側に定義)
                - `dev`がprivate networkに適した返すようになっている
            - `parsePartialIChainConfigJson(readBeaconParams(paramsFile))`によって、`fileParams`を設定
              - `paramsFile`によって読み込まれるファイルは、`chainConfigFromJson()`によって処理可能なフォーマットである必要があるが、`IChainConfig`を満たせばよい
            - createIChainConfig()によって、`IChainConfig`を生成する
        - createIChainForkConfig()によって、`IChainForkConfig`に変換して返す
          - `IChainForkConfig`は、`IChainConfig`と`IForkConfig`の交差型(複数の型の連結)となる
          - `IForkConfig`はfork schedileとhelper methodを持つ
  - initBeaconState() ... beacon stateの初期化処理(configが渡される)
    - createIBeaconConfig()
    - `args.genesisStateFile`があれば、そちらを読み込みstateを返す
    - ただし、`args.forceGenesis`が false である必要がある
  - createIBeaconConfig()
  - BeaconNode.init()

### network の種類について

- 現在、`mainnet`, `gnosis`, `goerli`, `ropsten`, `sepolia`, `dev`が定義されており、それぞれ default の設定をもつ
- networkの違いによって、返される`IChainConfig`の設定値が異なる

### chainConfig の設定

- `packages/config`が対象 package
- `packages/validator/test/unit/utils/interopConfigs.ts` に様々な設定が存在する
- `packages/config/src/chainConfig/networks` 内に各 network の定義がある
- `packages/config/src/chainConfig/presets` 内に mainnet.ts と minimal.ts があり、default 値が設定される

### CommandLine Option の確認

```
docker run chainsafe/lodestar:v1.2.2 --help
```
