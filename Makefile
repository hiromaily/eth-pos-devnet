
.PHONY:run-geth
run-geth:
	./scripts/start_geth.sh

.PHONY:run-beacon
run-beacon:
	./scripts/start_lodestar.sh


# check
# docker compose exec -it geth geth attach ipc://root/.ethereum/geth.ipc
# > eth.chainId()
# "0x1"

.PHONY:run-geth
clean:
	rm -rf ./execution/geth
	rm -rf ./execution/keystore
	rm -rf ./consensus/lodestar
