#!/usr/bin/env bash
# bin/pom-add.sh — inject a pom fragment into pom.xml
# Usage: bin/pom-add.sh <quality|jacoco|testcontainers> [pom.xml]
# Fragments are embedded here; Claude runs this script without reading template files.
set -euo pipefail

FRAGMENT="${1:?Usage: pom-add.sh <quality|jacoco|testcontainers> [pom.xml]}"
POM="${2:-pom.xml}"

[[ -f "$POM" ]] || { echo "error: $POM not found" >&2; exit 1; }

python3 - "$POM" "$FRAGMENT" <<'PYEOF'
import sys
import xml.etree.ElementTree as ET

pom_path, fragment = sys.argv[1], sys.argv[2]

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

def append_children(container, xml_str):
    added = []
    for child in ET.fromstring(xml_str):
        g = child.find(tag('groupId'))
        a = child.find(tag('artifactId'))
        key = f"{g.text}:{a.text}" if g is not None and a is not None else '?'
        if g is not None and a is not None and present(container, g.text, a.text):
            print(f"  skip (already present): {key}", file=sys.stderr)
            continue
        container.append(child)
        added.append(key)
    return added

# ── quality: Spotless + PMD + SpotBugs ────────────────────────────────────────
QUALITY = f'''<r xmlns="{NS}">
  <plugin>
    <groupId>com.diffplug.spotless</groupId>
    <artifactId>spotless-maven-plugin</artifactId>
    <version>2.43.0</version>
    <configuration>
      <java>
        <googleJavaFormat>
          <version>1.22.0</version>
          <style>GOOGLE</style>
        </googleJavaFormat>
      </java>
    </configuration>
    <executions>
      <execution>
        <id>spotless-check</id>
        <phase>verify</phase>
        <goals><goal>check</goal></goals>
      </execution>
    </executions>
  </plugin>
  <plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-pmd-plugin</artifactId>
    <version>3.21.0</version>
    <configuration>
      <printFailingErrors>true</printFailingErrors>
      <failOnViolation>true</failOnViolation>
    </configuration>
    <executions>
      <execution>
        <id>pmd</id>
        <phase>verify</phase>
        <goals><goal>check</goal></goals>
      </execution>
    </executions>
  </plugin>
  <plugin>
    <groupId>com.github.spotbugs</groupId>
    <artifactId>spotbugs-maven-plugin</artifactId>
    <version>4.8.3.1</version>
    <configuration>
      <effort>Max</effort>
      <threshold>Medium</threshold>
      <failOnError>true</failOnError>
    </configuration>
    <executions>
      <execution>
        <id>spotbugs</id>
        <phase>verify</phase>
        <goals><goal>check</goal></goals>
      </execution>
    </executions>
  </plugin>
</r>'''

# ── jacoco: merged unit + integration coverage ────────────────────────────────
JACOCO = f'''<r xmlns="{NS}">
  <plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
      <execution>
        <id>prepare-agent</id>
        <phase>initialize</phase>
        <goals><goal>prepare-agent</goal></goals>
      </execution>
      <execution>
        <id>prepare-agent-integration</id>
        <phase>pre-integration-test</phase>
        <goals><goal>prepare-agent-integration</goal></goals>
      </execution>
      <execution>
        <id>dump</id>
        <phase>post-integration-test</phase>
        <goals><goal>dump</goal></goals>
        <configuration>
          <address>localhost</address>
          <port>6300</port>
          <reset>true</reset>
          <destFile>${{project.build.directory}}/jacoco-it.exec</destFile>
        </configuration>
      </execution>
      <execution>
        <id>merge</id>
        <phase>post-integration-test</phase>
        <goals><goal>merge</goal></goals>
        <configuration>
          <fileSets>
            <fileSet>
              <directory>${{project.build.directory}}</directory>
              <includes>
                <include>jacoco.exec</include>
                <include>jacoco-it.exec</include>
              </includes>
            </fileSet>
          </fileSets>
          <destFile>${{project.build.directory}}/jacoco-merged.exec</destFile>
        </configuration>
      </execution>
      <execution>
        <id>report</id>
        <phase>verify</phase>
        <goals><goal>report</goal></goals>
        <configuration>
          <dataFile>${{project.build.directory}}/jacoco-merged.exec</dataFile>
          <outputDirectory>${{project.reporting.outputDirectory}}/jacoco</outputDirectory>
        </configuration>
      </execution>
    </executions>
  </plugin>
</r>'''

# ── testcontainers: BOM + test dependencies ───────────────────────────────────
TC_BOM = f'''<r xmlns="{NS}">
  <dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>testcontainers-bom</artifactId>
    <version>1.19.3</version>
    <type>pom</type>
    <scope>import</scope>
  </dependency>
</r>'''

TC_DEPS = f'''<r xmlns="{NS}">
  <dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>junit-jupiter</artifactId>
    <scope>test</scope>
  </dependency>
  <dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>postgresql</artifactId>
    <scope>test</scope>
  </dependency>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-testcontainers</artifactId>
    <scope>test</scope>
  </dependency>
  <dependency>
    <groupId>io.rest-assured</groupId>
    <artifactId>rest-assured</artifactId>
    <version>5.4.0</version>
    <scope>test</scope>
  </dependency>
  <dependency>
    <groupId>org.wiremock</groupId>
    <artifactId>wiremock-standalone</artifactId>
    <version>3.3.1</version>
    <scope>test</scope>
  </dependency>
</r>'''

if fragment == 'quality':
    plugins = find_or_create(find_or_create(root, 'build'), 'plugins')
    added = append_children(plugins, QUALITY)
    print(f"quality: added {len(added)} plugin(s) to <build><plugins>: {', '.join(added) or 'none'}")

elif fragment == 'jacoco':
    plugins = find_or_create(find_or_create(root, 'build'), 'plugins')
    added = append_children(plugins, JACOCO)
    print(f"jacoco: added {len(added)} plugin(s) to <build><plugins>: {', '.join(added) or 'none'}")

elif fragment == 'testcontainers':
    dm_deps = find_or_create(find_or_create(root, 'dependencyManagement'), 'dependencies')
    bom_added = append_children(dm_deps, TC_BOM)
    deps = find_or_create(root, 'dependencies')
    dep_added = append_children(deps, TC_DEPS)
    print(f"testcontainers: added {len(bom_added)} BOM entry, {len(dep_added)} test dependencies")

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
