# Quick fix script for hanging Gradle builds
Write-Host "=== Fixing Gradle Hang ===" -ForegroundColor Cyan

# Step 1: Kill all Gradle/Java processes
Write-Host "`n1. Killing Gradle daemons..." -ForegroundColor Yellow
taskkill /F /IM java.exe 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ Killed Java processes" -ForegroundColor Green
} else {
    Write-Host "   - No Java processes running" -ForegroundColor Gray
}

# Step 2: Stop Gradle daemon properly
Write-Host "`n2. Stopping Gradle daemon..." -ForegroundColor Yellow
Push-Location android
.\gradlew.bat --stop 2>$null
Pop-Location
Write-Host "   ✓ Gradle daemon stopped" -ForegroundColor Green

# Step 3: Clean Flutter build
Write-Host "`n3. Cleaning Flutter build..." -ForegroundColor Yellow
flutter clean
Write-Host "   ✓ Build cleaned" -ForegroundColor Green

# Step 4: Clear Gradle cache (optional - only if really stuck)
$clearCache = Read-Host "`nClear Gradle cache? (y/N)"
if ($clearCache -eq "y" -or $clearCache -eq "Y") {
    Write-Host "   Clearing Gradle cache..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\caches" -ErrorAction SilentlyContinue
    Write-Host "   ✓ Cache cleared" -ForegroundColor Green
}

Write-Host "`n=== Done! You can now run: flutter build apk --release ===" -ForegroundColor Cyan

