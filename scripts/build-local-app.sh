#!/bin/bash
set -euo pipefail
# Standalone, universal build from this checkout. Distribution signing is separate.
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_source="$task_root/MongrelCalculator/MongrelCalculator"
task_output="${1:-$task_root/dist/Local-$(date +%Y%m%d-%H%M%S)}"
task_developer=/Library/Developer/CommandLineTools
task_app="$task_output/Mongrel Calculator.app"
export DEVELOPER_DIR="$task_developer"
if [[ -e "$task_app" ]]; then echo "Choose a fresh output directory." >&2; exit 1; fi
mkdir -p "$task_app/Contents/MacOS" "$task_app/Contents/Resources"
task_work="$(mktemp -d "$task_output/.objects.XXXXXX")"
trap 'rm -rf "$task_work"' EXIT
for task_arch in arm64 x86_64; do
    "$task_developer/usr/bin/swiftc" -O -swift-version 5 -strict-concurrency=complete -warnings-as-errors \
        -sdk "$task_developer/SDKs/MacOSX.sdk" -target "$task_arch-apple-macosx14.0" -parse-as-library \
        "$task_source"/App/*.swift "$task_source"/Engine/*.swift \
        "$task_source"/Views/*.swift "$task_source"/Theme/*.swift \
        -o "$task_work/$task_arch"
done
"$task_developer/usr/bin/lipo" -create "$task_work/arm64" "$task_work/x86_64" -output "$task_app/Contents/MacOS/MongrelCalculator"
ditto "$task_source/Resources" "$task_app/Contents/Resources"
python3 - "$task_root" "$task_app" <<'PY'
import pathlib, plistlib, re, sys
root, app = map(pathlib.Path, sys.argv[1:])
spec=(root/'MongrelCalculator/project.yml').read_text()
values={'$(DEVELOPMENT_LANGUAGE)':'en', '$(EXECUTABLE_NAME)':'MongrelCalculator',
        '$(PRODUCT_BUNDLE_IDENTIFIER)':'com.mongrel.calculator', '$(MACOSX_DEPLOYMENT_TARGET)':'14.0',
        '$(MARKETING_VERSION)':re.search(r'MARKETING_VERSION: (\S+)',spec)[1],
        '$(CURRENT_PROJECT_VERSION)':re.search(r'CURRENT_PROJECT_VERSION: (\S+)',spec)[1]}
info=plistlib.loads((root/'MongrelCalculator/MongrelCalculator/App/Info.plist').read_bytes())
info={k:values.get(v,v) if isinstance(v,str) else v for k,v in info.items()}
info['NSHighResolutionCapable']=True
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
(app/'Contents/PkgInfo').write_bytes(b'APPL????')
PY
codesign --force --sign - --options runtime "$task_app"
codesign --verify --strict "$task_app"
echo "Built: $task_app"
