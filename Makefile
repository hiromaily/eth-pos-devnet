
.PHONY:create-beacon-genesis
create-beacon-genesis:
	docker compose up create-beacon-chain-genesis

# check
# docker compose exec -it geth geth attach ipc://root/.ethereum/geth.ipc
# > eth.chainId()
# "0x1"
