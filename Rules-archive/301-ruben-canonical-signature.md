# 301 — Ruben's electronic signature: ONE canonical file. Never extract, never reconstruct.

Source: 2026-07-31 — Ruben directive: "This is my signature. Make a cline rule for my signature: signature2small.jpg - use that instead of the one you made."

## The canonical file

**Ruben's electronic signature is `signature2small.jpg`. That is the only acceptable source.**

| Property | Value |
|---|---|
| Canonical server path | `/var/www/emtskills/uploads/compliance/regulator_correspondence/ruben_major_signature_canonical.jpg` |
| Local origin | `/Users/rubenmajor/Downloads/signature2small.jpg` |
| SHA-256 | `2da83b2b811629cb62051a99b6503c4c740a2049c9e45451b3ce06bb515fec57` |
| Format | JPEG, 256x76 px, 4,241 bytes |
| Data URI mime | `data:image/jpeg;base64,` (NOT png) |

Verify before use:
```
sha256sum /var/www/emtskills/uploads/compliance/regulator_correspondence/ruben_major_signature_canonical.jpg
```
If the hash does not match, stop and ask Ruben. Do not proceed with a signature you cannot verify.

## The bright-line rule

**NEVER extract, crop, reconstruct, or scavenge a signature from another document.** On 2026-07-31 an agent pulled a signature image out of page 4 of a previously signed PDF (`uploads/dshs/F01-13067_MD_Change_Rodriguez_SIGNED.pdf`), pixel-diffed it against another candidate, confirmed a 0.0 match, and shipped it onto a regulator filing. The forensic work was clean and the result was still the wrong file. Ruben had to correct it.

Banned sourcing methods:
- `pdfimages` extraction from any signed PDF
- Cropping a scan or screenshot
- Reusing an image found in `uploads/` because it looks like a signature
- Any file named `ruben_major_signature.png` (the superseded 972x600 extraction — do not use)

The only legal move is the canonical file above. If it is missing from the server, re-upload it from `~/Downloads/signature2small.jpg` and verify the hash.

## Embedding

Embed as a **base64 data URI**, not a filesystem `src`. A file-path `src` does not reliably embed in `wkhtmltopdf` output.

```python
import io, base64
SIG = '/var/www/emtskills/uploads/compliance/regulator_correspondence/ruben_major_signature_canonical.jpg'
b64 = base64.b64encode(io.open(SIG, 'rb').read()).decode()
tag = '<img class=si src="data:image/jpeg;base64,' + b64 + '">'
```

CSS that renders correctly at this aspect ratio:
```css
.si { width: 2.4in; height: auto; display: block; margin-bottom: 2pt; }
```

## Post-generation verification (mandatory)

After generating any signed PDF, confirm the correct signature landed:
```
pdfimages -list <file>.pdf | grep -c '256    76'   # must be >= 1
pdfimages -list <file>.pdf | grep -c 972           # must be 0 (old extraction)
```
A PDF that shows the 972x600 image is carrying the wrong signature and must be regenerated.

## Signature block that accompanies it

Per Ruben's 2026-07-31 spec, the signature image sits above:

```
Best, &c
[signature image]
Ruben Major, EMT-Paramedic, J.D., M.A.
CEO, EMS University, LLC d.b.a. EMS Universal Education
"We Don't Follow the Standards, We Set Them."
www.emsuniversity.com
facebook.com/emsuniversity
twitter.com/emsuniversity
(800) 728-0209
```

## Self-check before generating any signed document

1. Am I using `ruben_major_signature_canonical.jpg`? If no → stop.
2. Did I verify the SHA-256? If no → verify it.
3. Is the data URI mime `image/jpeg`? If it says `image/png` → wrong file.
4. Did I extract this from another PDF? If yes → **violation**, use the canonical file.
5. After generating, did `pdfimages -list` show 256x76 and zero 972? If no → regenerate.

## Cross-references

- Rule 01 — Ruben voice and persona (the signature block wording is part of the persona)
- Rule 02 — no apologies in student-facing email (same regulator-facing document class)
- Rule 144 — server paths need `ssh_command`, never local `write_to_file`
- Rule 263 — verify before claiming (a signature you did not hash-verify is unverified)

## Source incident

2026-07-31 — during the AZDHS July 2026 NOI consolidated response, an agent extracted a signature from `uploads/dshs/F01-13067_MD_Change_Rodriguez_SIGNED.pdf` page 4, validated it by pixel diff against `sig_program_coordinator_2.png` (diff = 0.0), and embedded it in the Response plus both Enclosures. Ruben reviewed the shipped PDFs and supplied the real file: "This is my signature... use that instead of the one you made." All three documents were regenerated with the canonical file, verified 256x76 present and 972x600 absent in every PDF.

## Last updated

2026-07-31 — initial.
