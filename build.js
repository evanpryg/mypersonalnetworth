const fs = require('fs');
const path = require('path');

function compile() {
  const rootDir = __dirname;
  let indexHtml = fs.readFileSync(path.join(rootDir, 'index.html'), 'utf8');

  // Regex to match <?!= include('FileName'); ?>
  const includeRegex = /<\?!= include\('([^']+)'\);\s*\?>/g;

  let match;
  while ((match = includeRegex.exec(indexHtml)) !== null) {
    const macro = match[0];
    const fileName = match[1];
    
    // Find the file (either .html or .js or similar)
    let filePath = path.join(rootDir, `${fileName}.html`);
    if (!fs.existsSync(filePath)) {
      filePath = path.join(rootDir, `${fileName}.js`);
    }
    
    if (!fs.existsSync(filePath)) {
      console.error(`Error: File ${fileName} not found!`);
      process.exit(1);
    }
    
    const fileContent = fs.readFileSync(filePath, 'utf8');
    
    // Wrap it in appropriate tags if it doesn't have them
    let replacement = fileContent;
    const trimmed = fileContent.trim();
    if (!trimmed.startsWith('<')) {
      if (fileName.toLowerCase().includes('style')) {
        replacement = `<style>\n${fileContent}\n</style>`;
      } else if (fileName.toLowerCase().includes('script')) {
        replacement = `<script>\n${fileContent}\n</script>`;
      }
    }
    
    indexHtml = indexHtml.replace(macro, replacement);
    // Reset regex index because we modified the string length
    includeRegex.lastIndex = 0;
  }

  // Create dist directory if it doesn't exist
  const distDir = path.join(rootDir, 'dist');
  if (!fs.existsSync(distDir)) {
    fs.mkdirSync(distDir);
  }

  fs.writeFileSync(path.join(distDir, 'index.html'), indexHtml, 'utf8');
  console.log('✅ App compiled successfully to dist/index.html');
}

compile();
