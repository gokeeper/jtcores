#!/bin/bash
# Run inside jotego/jtcore20 with this checkout mounted at /jtcores.
set -eo pipefail
git config --global --add safe.directory /jtcores
cd /jtcores
source modules/jtframe/bin/setprj.sh >/dev/null
export PATH="$PATH:/usr/local/go/bin"
mkdir -p build-info

jtframe cfgstr cps3 --target=mister --nodbg --output bash > build-info/macros.txt
if grep -Eq '^export (BETA|JTFRAME_UNLOCKKEY|JTFRAME_SKIP)=' build-info/macros.txt; then
    echo 'CPS3 configuration still enables beta locking or skips this target.' >&2
    exit 1
fi

jtframe files plain cps3 --target=mister
mv files build-info/sources.txt

# Use the helper's build commands in the environment already initialized above.
# xjtcore.sh is not executable and would source setprj.sh a second time.
jtframe mra --nodbg --skipROM --skipPocket cps3
jtutil seed --max-trials 8 cps3 -mister --nodbg --nolinter
test -s release/mister/jtcps3.rbf

found=0
while IFS= read -r -d '' mra; do
    found=1
    if grep -q 'jtbeta\.zip' "$mra"; then
        echo "Generated MRA still requires a beta key: $mra" >&2
        exit 1
    fi
done < <(find release/mra -type f -name '*3rd*Strike*.mra' -print0)
if [ "$found" -ne 1 ]; then
    echo 'No generated 3rd Strike MRA was found.' >&2
    exit 1
fi
sha256sum release/mister/jtcps3.rbf > build-info/SHA256SUMS
