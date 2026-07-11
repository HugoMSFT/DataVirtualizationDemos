import argparse
import io
from pathlib import Path
import tarfile


APP_NAME = "Pro Click Mini Configurator.app"
EXECUTABLE_NAME = "ProClickConfigurator"


def add_directory(archive: tarfile.TarFile, name: str) -> None:
    entry = tarfile.TarInfo(name)
    entry.type = tarfile.DIRTYPE
    entry.mode = 0o755
    entry.mtime = 0
    archive.addfile(entry)


def add_bytes(archive: tarfile.TarFile, name: str, content: bytes) -> None:
    entry = tarfile.TarInfo(name)
    entry.size = len(content)
    entry.mode = 0o644
    entry.mtime = 0
    archive.addfile(entry, io.BytesIO(content))


def create_bundle(publish_dir: Path, info_plist: Path, output: Path) -> None:
    executable = publish_dir / EXECUTABLE_NAME
    if not executable.is_file():
        raise FileNotFoundError(f"Published executable not found: {executable}")

    output.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(output, "w:gz", format=tarfile.PAX_FORMAT) as archive:
        contents_dir = f"{APP_NAME}/Contents"
        macos_dir = f"{contents_dir}/MacOS"
        add_directory(archive, APP_NAME)
        add_directory(archive, contents_dir)
        add_directory(archive, macos_dir)
        add_bytes(
            archive,
            f"{contents_dir}/Info.plist",
            info_plist.read_bytes(),
        )

        for source in sorted(publish_dir.iterdir()):
            if not source.is_file() or source.suffix == ".pdb":
                continue

            entry = archive.gettarinfo(
                str(source),
                arcname=f"{macos_dir}/{source.name}",
            )
            entry.mode = 0o755
            entry.uid = 0
            entry.gid = 0
            entry.uname = ""
            entry.gname = ""
            with source.open("rb") as stream:
                archive.addfile(entry, stream)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Package a self-contained .NET macOS publish as an app bundle."
    )
    parser.add_argument("publish_dir", type=Path)
    parser.add_argument("info_plist", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    create_bundle(
        arguments.publish_dir.resolve(),
        arguments.info_plist.resolve(),
        arguments.output.resolve(),
    )


if __name__ == "__main__":
    main()
