#!/usr/bin/env bash
# bin/pom-add.sh — inject a pom fragment into pom.xml
# Usage: bin/pom-add.sh <quality|jacoco|testcontainers> [pom.xml]
# Reads fragment from templates/pom-fragments/<fragment>.xml relative to this script.
set -euo pipefail

FRAGMENT="${1:?Usage: pom-add.sh <quality|jacoco|testcontainers> [pom.xml]}"
POM="${2:-pom.xml}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../templates/pom-fragments/$FRAGMENT.xml"

[[ -f "$POM" ]]      || { echo "error: $POM not found" >&2; exit 1; }
[[ -f "$TEMPLATE" ]] || { echo "error: template not found: $TEMPLATE" >&2; exit 1; }

python3 - "$POM" "$FRAGMENT" "$TEMPLATE" <<'PYEOF'
import sys
import xml.etree.ElementTree as ET

pom_path, fragment, template_path = sys.argv[1], sys.argv[2], sys.argv[3]

ET.register_namespace('', 'http://maven.apache.org/POM/4.0.0')
ET.register_namespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance')

NS = 'http://maven.apache.org/POM/4.0.0'
ns = {'m': NS}

tree = ET.parse(pom_path)
root = tree.getroot()

def tag(name):
    return f'{{{NS}}}{name}'

def find_or_create(parent, name):
    el = parent.find(f'm:{name}', ns)
    if el is None:
        el = ET.SubElement(parent, tag(name))
    return el

def present(container, group_id, artifact_id):
    for child in container:
        g = child.find(tag('groupId'))
        a = child.find(tag('artifactId'))
        if g is not None and a is not None and g.text == group_id and a.text == artifact_id:
            return True
    return False

def append_children(container, source_el):
    added = []
    for child in source_el:
        g = child.find(tag('groupId'))
        a = child.find(tag('artifactId'))
        key = f"{g.text}:{a.text}" if g is not None and a is not None else '?'
        if g is not None and a is not None and present(container, g.text, a.text):
            print(f"  skip (already present): {key}", file=sys.stderr)
            continue
        container.append(child)
        added.append(key)
    return added

# Template files contain bare <plugin> or <dependency> elements (no wrapper tag).
# Wrap in a dummy root with the Maven namespace so ET parses the fragment correctly.
raw = open(template_path).read()
frag = ET.fromstring(f'<r xmlns="{NS}">{raw}</r>')

if fragment in ('quality', 'jacoco'):
    plugins = find_or_create(find_or_create(root, 'build'), 'plugins')
    added = append_children(plugins, frag)
    print(f"{fragment}: added {len(added)} plugin(s): {', '.join(added) or 'none (all present)'}")

elif fragment == 'testcontainers':
    # testcontainers.xml contains only test <dependency> elements (BOM is intentionally
    # commented out — Spring Boot parent POM already manages testcontainers versions).
    deps = find_or_create(root, 'dependencies')
    added = append_children(deps, frag)
    print(f"testcontainers: added {len(added)} test dependencies: {', '.join(added) or 'none (all present)'}")

else:
    print(f"error: unknown fragment '{fragment}'. Choose: quality, jacoco, testcontainers", file=sys.stderr)
    sys.exit(1)

ET.indent(tree, space='    ')
with open(pom_path, 'wb') as f:
    f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
    tree.write(f, encoding='utf-8', xml_declaration=False)
    f.write(b'\n')

print(f"written: {pom_path}")
PYEOF
