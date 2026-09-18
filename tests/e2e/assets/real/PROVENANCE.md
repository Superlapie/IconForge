# Real-model E2E assets

These are real, textured glTF sample models from the KhronosGroup
`glTF-Sample-Models` repository. They are deliberately separate from the
small procedural fixtures in `/fixtures`; the E2E test below exercises the
same import and render path against externally authored models.

The files are pinned to repository commit
`d7a3cc8e51d7c573771ae77a57f16b0662a905c6`:

- [Avocado.glb](https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/d7a3cc8e51d7c573771ae77a57f16b0662a905c6/2.0/Avocado/glTF-Binary/Avocado.glb)
  — [model README and CC0 notice](https://github.com/KhronosGroup/glTF-Sample-Models/blob/d7a3cc8e51d7c573771ae77a57f16b0662a905c6/2.0/Avocado/README.md)
- [BoomBox.glb](https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/d7a3cc8e51d7c573771ae77a57f16b0662a905c6/2.0/BoomBox/glTF-Binary/BoomBox.glb)
  — [model README and CC0 notice](https://github.com/KhronosGroup/glTF-Sample-Models/blob/d7a3cc8e51d7c573771ae77a57f16b0662a905c6/2.0/BoomBox/README.md)

The upstream model READMEs state that Microsoft waived copyright and related
rights to these assets to the extent possible under law. The local
`SHA256SUMS` file makes accidental replacement detectable.

These files are test/demo inputs only. They are not required by the runtime
and are not a dependency on any game repository.
