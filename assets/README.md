## Asset Directory

This directory contains all binary assets used by Avalon.  To preserve your
existing models, wings and other files, copy the contents of your original
`asset/` directory here.  This patch does not include the binary files
themselves in order to keep the repository lightweight.

Contents:

- `models/` – VRM files for each fairy (e.g. `nina.vrm`, `carol.vrm`).
- `winged-models/` – winged variants of selected models.
- `wings/` – wing textures and manifests.

You can leave the `.keep` files in place if you have not yet copied your
assets.  They will ensure that empty directories remain under version
control.