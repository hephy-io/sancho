#!/bin/bash

# --- CONFIG ---
DATE_STAMP=$(date +%d%m%y)
TX_BODY="${DATE_STAMP}-tx.body"
PAYMENT_ADDR=$(cat /path/to/payment.addr)
PAYMENT_VKEY=${PAYMENT_VKEY:-/path/to/payment.vkey}
DREP_VKEY=${DREP_VKEY:-/path/to/drep.vkey}
SPO_VKEY=${SPO_VKEY:-/path/to/spo.vkey}
BASE_URL="https://url/to/metadata/files"

DRY_RUN=false
[[ "$1" == "--dry-run" ]] && DRY_RUN=true

# 1. AUTO-FETCH "CLEAN" UTXO (ADA Only)
if [ "$DRY_RUN" = false ]; then
    echo "Searching for a clean UTXO..."
    UTXO=$(cardano-cli query utxo --address "$PAYMENT_ADDR" --testnet-magic 4 --out-file /dev/stdout | \
    jq -r 'to_entries | map(select(.value.value | length == 1 and has("lovelace"))) | sort_by(.value.value.lovelace) | last | .key')

    if [ "$UTXO" == "null" ] || [ -z "$UTXO" ]; then
        echo "ERROR: No pure ADA UTXOs found."; exit 1
    fi
    echo "Using UTXO: $UTXO"
else
    echo "--- DRY RUN MODE ---"
    UTXO="DUMMY_UTXO_FOR_TESTING#0"
fi

# 2. PROCESS MANIFEST
VOTE_FILES_CMD=""
HAS_DREP=0; HAS_SPO=0

while read -r ID ROLE VOTE METADATA_FILE; do
    [[ -z "$ID" || "$ID" == "#"* ]] && continue
    [[ "$ROLE" == "drep" ]] && HAS_DREP=1
    [[ "$ROLE" == "spo" ]] && HAS_SPO=1

    # Auto-Hash Metadata
    HASH=$(b2sum -l 256 "metadata/$METADATA_FILE" | awk '{print $1}')
    URL="${BASE_URL}/${METADATA_FILE}"
    OUT_VOTE="${ID//[:#]/_}_${ROLE}.vote"

    [[ "$ROLE" == "drep" ]] && FLAG="--drep-verification-key-file $DREP_VKEY" || FLAG="--stake-pool-verification-key-file $SPO_VKEY"
        cardano-cli conway governance vote create \
        --$(echo "$VOTE" | tr '[:upper:]' '[:lower:]') \
        --governance-action-tx-id "${ID%#*}" \
        --governance-action-index "${ID#*#}" \
        $FLAG \
        --anchor-url "$URL" \
        --anchor-data-hash "$HASH" \
        --out-file "$OUT_VOTE"

    VOTE_FILES_CMD+="--vote-file $OUT_VOTE "
done < governance.list

# 3. BUILD (Only if not Dry Run)
if [ "$DRY_RUN" = false ]; then
    WITNESS_COUNT=$(( 1 + HAS_DREP + HAS_SPO ))
    cardano-cli conway transaction build \
        --testnet-magic 4 \
        --tx-in "$UTXO" \
        $VOTE_FILES_CMD \
        --change-address "$PAYMENT_ADDR" \
        --witness-override $WITNESS_COUNT \
        --out-file "$TX_BODY"

    echo "Success! Build created at $TX_BODY"
    cardano-cli debug transaction view --tx-body-file "$TX_BODY"
else
    echo "Dry run complete. Hashes and .vote files are valid."
fi
