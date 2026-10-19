# Portfolio

A three-screen photo site written in Dart: a landing page, an index of photos, and a viewer that shows each photo beside its story or poem.

## Adding a photo

1. Put the image in `web/photos/`. Start the name with a number so it sorts where you want it:
   `02-flinders-rain.jpg`
2. Optional: add a text file with the same name, `02-flinders-rain.md`:

   ```
   title: Flinders, Raining
   place: Melbourne
   ---
   Your story or poem here.
   Line breaks are kept.

   A blank line starts a new paragraph or stanza.
   ```

   No text file? The title comes from the file name and the story area stays empty.
3. Commit and push. GitHub rebuilds and publishes the site in about a minute.

Photos are shown in file-name order. The part after the number becomes the link, e.g. `#/work/flinders-rain`.
Keep images around 2000–2500px on the long edge so they load quickly.

## Site name and landing photo

Edit `web/site.json`:

```json
{
  "name": "BAYNE",
  "tagline": "Night streets, strangers, and the stories they leave behind.",
  "featured": "little-collins"
}
```

`featured` is the slug of the photo used behind the landing page (defaults to the first photo).

## First-time deploy

1. Create a new repository on GitHub and push this folder to its `main` branch.
2. In the repository go to **Settings → Pages** and set **Source** to **GitHub Actions**.
3. Push (or run the workflow from the **Actions** tab). The site appears at
   `https://<your-username>.github.io/<repo-name>/`.

For a custom domain, add it under Settings → Pages.

## Running it locally

Needs the [Dart SDK](https://dart.dev/get-dart).

```sh
dart pub get
dart run tool/build_manifest.dart
dart compile js -o web/main.dart.js web/main.dart
cd web && python3 -m http.server 8080
```

Then open http://localhost:8080.

## Files

| Path | What it is |
| --- | --- |
| `web/main.dart` | All page logic: routing, views, transitions, keyboard and swipe |
| `web/styles.css` | All styling |
| `web/index.html` | Page shell |
| `web/site.json` | Site name, tagline, landing photo |
| `web/photos/` | Your images and their `.md` stories |
| `tool/build_manifest.dart` | Builds `web/photos.json` from the photos folder |
| `.github/workflows/deploy.yml` | Builds and publishes to GitHub Pages on every push |

Viewer controls: ← / → keys or swipe for previous/next, Esc to go back.
