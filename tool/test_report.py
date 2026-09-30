"""Turn Flutter --machine output into a readable summary and JUnit artifact."""
import json
import pathlib
import sys
import xml.etree.ElementTree as ET

source = pathlib.Path(sys.argv[1])
tests, failures, results = {}, {}, {}
for line in source.read_text(encoding="utf-8-sig").splitlines():
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        continue
    if not isinstance(event, dict):
        continue
    kind = event.get("type")
    if kind == "testStart":
        tests[event["test"]["id"]] = event["test"]["name"]
    elif kind == "error":
        failures.setdefault(event["testID"], []).append(str(event.get("error", "")))
    elif kind == "testDone" and not event.get("hidden", False):
        results[event["testID"]] = event

suite = ET.Element("testsuite", name="Pocket Arcade", tests=str(len(results)))
lines = ["# Pocket Arcade test report", "", "| Result | Test |", "| --- | --- |"]
failed = 0
for identifier, event in results.items():
    name = tests.get(identifier, str(identifier))
    case = ET.SubElement(suite, "testcase", name=name, classname="flutter")
    if event.get("skipped"):
        label = "SKIP"
        ET.SubElement(case, "skipped")
    elif event.get("result") != "success":
        label = "FAIL"
        failed += 1
        ET.SubElement(case, "failure").text = "\n".join(failures.get(identifier, ["Test failed"]))
    else:
        label = "PASS"
    lines.append(f"| {label} | {name.replace('|', '/').replace(chr(10), ' ')} |")
suite.set("failures", str(failed))
lines[2:2] = [f"**{len(results)} tests reported; {failed} failed.**", ""]
if not results:
    lines.append("No test results were produced. Check the build log for an early failure.")
source.with_name("summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
ET.ElementTree(suite).write(source.with_name("junit.xml"), encoding="utf-8", xml_declaration=True)
print("\n".join(lines))
