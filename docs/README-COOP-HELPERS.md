# Cooperative Helpers (AI-only, no UI changes)

Workflows + scripts so Alexandria can collaborate with Tracy (art), Nina (3D), and Charlotte (pipelines) entirely via data artifacts.

## Workflows
- alexandria-build-all.yml — create seed+bible+timeline+npcs+atlas
- alexandria-helpers.yml — figures + continuity + author scenes + bundle
- tracy-art-suite.yml — artboard briefs
- nina-3d-suite.yml — VRM index + SceneKit stubs (reads asset/models, asset/winged-models, asset/wings)
- charlotte-pipelines.yml — SSML scripts + translation stubs
- avalon-helpers-all.yml — orchestrate all suites

## Outputs (examples)
- pages/apps/alexandria/worlds/codex/figures-<world>.json
- pages/apps/alexandria/worlds/reports/continuity-<world>.json
- pages/apps/alexandria/worlds/exports/Scenes-<world>.md
- pages/apps/alexandria/worlds/exports/WorldBundle-<world>.zip
- pages/apps/alexandria/worlds/artboards/artboard-<world>.json
- pages/apps/overseers/vrm-index.json
- pages/apps/alexandria/worlds/3d/SceneKit-<world>.json
- pages/apps/alexandria/worlds/pipelines/pipeline-<world>.json
- pages/apps/alexandria/worlds/pipelines/tts/scene-*.ssml
- pages/apps/alexandria/worlds/pipelines/translations/Scenes-<world>.<lang>.md
