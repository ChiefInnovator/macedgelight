"""Offline integrity checks for this vendored runtime; no model or hardware checks."""
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
for path in root.rglob('*.json'):
    json.loads(path.read_text())

# Resolve the actual Stage 7/9 caller values against the installed bundle.
review = (root / 'skills/egm-review/SKILL.md').read_text()
for heading in ('Critic Review', 'Implementation Readiness Test'):
    section = review.split('### Subflow: ' + heading, 1)[1]
    call = section.split('2.  **Notify User', 1)[0]
    reviewers = re.search(r'with reviewers `\[([^]]+)\]', call).group(1)
    names = {name.strip() for name in reviewers.split(',')}
    for name in names:
        assert (root / 'agents' / (name + '.md')).is_file(), name
    standards = json.loads(re.search(r'standards\s+`([^`]+)`', call).group(1))
    assert set(standards) <= names
    for name in standards.values():
        assert (root / 'resources/document_standards' / (name + '.md')).is_file(), name

for group in re.findall(r'Reviewers: \[([^]]+)\]', review):
    for name in group.split(','):
        assert (root / 'agents' / (name.strip() + '.md')).is_file(), name

schema = json.loads((root / 'skills/egm-bootstrap/references/worker-return.schema.json').read_text())
item = schema['properties']['subtree_index']['items']
contract = {'path', 'summary', 'interface', 'invariants', 'side_effects'}
assert set(item['required']) == contract
assert all(item['properties'][key]['type'] == 'array' for key in contract - {'path', 'summary'})

skills = sorted(root.glob('skills/egm-*'))
assert len(skills) == 7
for skill in skills:
    assert (skill / 'SKILL.md').read_text().startswith('---\nname: ')
    icon = ET.parse(skill / 'assets/icon.svg').getroot()
    assert icon.attrib['viewBox'] == '0 0 24 24'
    plan = (skill / 'TEST.md').read_text()
    assert '../../TESTING.md' not in plan
    assert (skill / '../../INSTALLATION.md').resolve().is_file()

scenarios = (root / 'skills/egm-review/test_scenarios.yaml').read_text()
for target in re.findall(r'\.agents/skills/egm-review/references/fixtures/[\w-]+\.md', scenarios):
    assert (root.parent / target).is_file(), target
assert len(re.findall(r'GoldfishContext: \[\]', scenarios)) == len(re.findall(r'user_input:', scenarios))

routing = (root / 'skills/impeccable/reference/routing.md').read_text()
assert 'positively identified as web' in routing
assert (root / 'skills/impeccable/reference/macos.md').is_file()
assert 'reference/macos.md' in (root / 'skills/impeccable/SKILL.md').read_text()
print('PASS: JSON, reviewer/standard resolution, worker schema contract, seven skills/icons, scenario fixtures, desktop routing guards')
