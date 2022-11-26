# How to create devnet or localnet for another consensus client

## 挙動の説明

1. `go-ethereum` で proof-of-work development node を genesis config によって初期化する
2. `Prysm beacon chain` で proof-of-stake development node を genesis config によって初期化する
3. `go-ethereum`で mining を開始し、並行して Prysm の proof-of-stake node を走らせる
4. `go-ethereum` node の mining difficulty が一度 `50`に達したら, その node は Prysm にブロックのコンセンサスを駆動させることによって、proof-of-stake mode に switch する

## Prysm の設定

- [config.yml](./consensus/config.yml)は変更することも可能。例えば、`BELLATRIX_FORK_EPOCH`によって各 slot 間隔が 4 秒になっているため、処理が早く進む。

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
- 現在の example は`prysm`を使っている
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

| Prysm                     | Lodestar                       | 説明                                                               |
| ------------------------- | ------------------------------ | ------------------------------------------------------------------ |
| --datadir                 | --dataDir                      |                                                                    |
| --min-sync-peers          | --targetPeers ??               | 0 を設定する                                                       |
| --interop-genesis-state   | x ??                           | /consensus/genesis.ssz を指定するもの                              |
| --interop-eth1data-votes  | x ??                           | TODO: prysm のコードを読まないとわからない                         |
| --bootstrap-node          | --bootnodes ??                 | 空を設定する。default は空                                         |
| --chain-config-file       |                                | /consensus/config.yml を指定するもの                               |
| --chain-id                | x                              | 32382 を設定する。設定できないので、コードに手を入れる必要がある？ |
| --rpc-host                | --rest.address (--rest も必要) | 0.0.0.0 を設定する                                                 |
| --grpc-gateway-host       | x                              | 不要                                                               |
| --execution-endpoint      | --execution.urls               |                                                                    |
| --accept-terms-of-use     | x                              | 不要                                                               |
| --jwt-secret              | --jwt-secret                   |                                                                    |
| --suggested-fee-recipient | --suggestedFeeRecipient        |                                                                    |

- TODO: 場合によっては、lodestar を fork してハードコードされている箇所の修正が必要になるかもしれない

## Lodestar

### Local testnet について

- [Local testnet](https://chainsafe.github.io/lodestar/usage/local/)
- `dev`サブコマンドをつけて起動することで、beacon node と validator が立ち上がる
- 今回`dev`モードで起動する必要があるのか？`beacon`モードでもいいのかもしれない。

### TODO: `dev`モードの内部的な挙動について

- [Github lodestar cli](https://github.com/ChainSafe/lodestar/tree/unstable/packages/cli)
-

### CommandLine Option の確認

```
docker run chainsafe/lodestar:v1.2.2 --help
```
