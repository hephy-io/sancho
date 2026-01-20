#!/bin/bash

DATE_STAMP=$(date +%d%m%y)
TX_BODY="${DATE_STAMP}-tx.body"
NETWORK="--testnet-magic 4"

# Build witness arguments based on what was transferred from COLD environment
WITNESS_ARGS="--witness-file payment.witness"
[ -f drep.witness ] && WITNESS_ARGS+=" --witness-file drep.witness"
[ -f spo.witness ] && WITNESS_ARGS+=" --witness-file spo.witness"

# Assemble Witness Signatures
cardano-cli conway transaction assemble --tx-body-file "$TX_BODY" $WITNESS_ARGS --out-file "${DATE_STAMP}-tx.signed"
# Submit transaction and copy output to .txt file for future reference
cardano-cli conway transaction submit --tx-file "${DATE_STAMP}-tx.signed" $NETWORK 2>&1 | tee tx_hash.txt

# Archive everything
mkdir -p archive/"$DATE_STAMP"
mv *.vote *.witness *.body *.signed *.txt archive/"$DATE_STAMP"/
