const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function copyFolderRecursiveSync(source, target) {
  if (!fs.existsSync(target)) {
    fs.mkdirSync(target, { recursive: true });
  }

  if (fs.lstatSync(source).isDirectory()) {
    const files = fs.readdirSync(source);
    files.forEach((file) => {
      const curSource = path.join(source, file);
      const curTarget = path.join(target, file);
      if (fs.lstatSync(curSource).isDirectory()) {
        copyFolderRecursiveSync(curSource, curTarget);
      } else {
        fs.copyFileSync(curSource, curTarget);
      }
    });
  }
}

try {
  console.log('Building Flutter Web Client...');
  execSync('flutter build web --release', {
    cwd: path.join(__dirname, '..', 'task_manager_app'),
    stdio: 'inherit',
  });
  console.log('Flutter Web Client build complete!');

  const sourceDir = path.join(__dirname, '..', 'task_manager_app', 'build', 'web');
  const targetDir = path.join(__dirname, '..', 'public');

  console.log(`Copying client files from ${sourceDir} to ${targetDir}...`);
  copyFolderRecursiveSync(sourceDir, targetDir);
  console.log('Client files copied successfully!');
} catch (error) {
  console.error('Error building and copying client:', error);
  process.exit(1);
}
