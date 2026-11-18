"""Package a stylesheet contribution without a renderer or extension-host code."""

import json
from pathlib import Path
import sys
from xml.sax.saxutils import escape
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED


def package(source, output):
    manifest = json.loads((source / "package.json").read_text())
    name, publisher, version = (escape(manifest[key]) for key in ("name", "publisher", "version"))
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        def write(name, content):
            entry = ZipInfo(name)
            entry.compress_type = ZIP_DEFLATED
            archive.writestr(entry, content)

        write("extension.vsixmanifest", f'''<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="{name}" Version="{version}" Publisher="{publisher}" />
    <DisplayName>Markdown Preview Style</DisplayName>
    <Description xml:space="preserve">Fira Sans preview typography and Mermaid styling.</Description>
    <Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.121.0" /></Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code" /></Installation>
  <Dependencies />
  <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" /></Assets>
</PackageManifest>
''')
        write("[Content_Types].xml", '''<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json" />
  <Default Extension="css" ContentType="text/css" />
  <Default Extension="md" ContentType="text/markdown" />
  <Default Extension="vsixmanifest" ContentType="text/xml" />
</Types>
''')
        for name in ("package.json", "preview.css", "vscode.css", "README.md"):
            write("extension/" + name, (source / name).read_bytes())


if __name__ == "__main__":
    package(Path(sys.argv[1]), Path(sys.argv[2]))
