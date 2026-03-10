# Build Flutter web
flutter build web --base-href "/mview-web/" --release
Copy-Item build\web\index.html build\web\404.html -Force

# Deploy to gh-pages
git --work-tree build/web add --all
if (git diff --cached --quiet) {
    Write-Host "⚠️  Nothing to commit (no changes detected)"
} else {
    git commit -m "deploy new build"
}
git push origin HEAD:gh-pages --force

Write-Host ""
Write-Host "✅ Done! Website updated at:"
Write-Host "👉 https://ninhlhpnd.github.io/mview-web/"
