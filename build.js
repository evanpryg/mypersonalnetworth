const fs = require('fs');
const path = require('path');
const vm = require('vm');

// Parse every <script> block and fail the build on a syntax error. Without
// this a broken script is bundled silently, the browser refuses the whole
// block, and the app ships dead — CI runs this same command, so a parse
// error now stops the deploy instead of reaching the live site.
function checkSyntax(fileName, html) {
  const scriptRegex = /<script\b[^>]*>([\s\S]*?)<\/script>/gi;
  let m;
  let index = 0;
  while ((m = scriptRegex.exec(html)) !== null) {
    index++;
    const code = m[1];
    if (!code.trim()) continue;
    try {
      new vm.Script(code, { filename: `${fileName} (script #${index})` });
    } catch (err) {
      console.error(`\n❌ Syntax error in ${fileName}, script block #${index}:`);
      console.error(`   ${err.message}`);
      const line = (err.stack.match(/script #\d+\):(\d+)/) || [])[1];
      if (line) {
        const src = code.split('\n');
        const n = Number(line);
        for (let i = Math.max(0, n - 2); i < Math.min(src.length, n + 1); i++) {
          console.error(`   ${i + 1 === n ? '>' : ' '} ${src[i]}`);
        }
      }
      process.exit(1);
    }
  }
}

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
    checkSyntax(path.basename(filePath), fileContent);

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

  // Static assets (PWA manifest, app icons) live in public/ and are copied
  // verbatim — gh-pages only ever receives the contents of dist/.
  const publicDir = path.join(rootDir, 'public');
  if (fs.existsSync(publicDir)) {
    let copied = 0;
    const copyDir = (from, to) => {
      fs.mkdirSync(to, { recursive: true });
      for (const entry of fs.readdirSync(from, { withFileTypes: true })) {
        const src = path.join(from, entry.name);
        const dest = path.join(to, entry.name);
        if (entry.isDirectory()) copyDir(src, dest);
        else { fs.copyFileSync(src, dest); copied++; }
      }
    };
    copyDir(publicDir, distDir);
    console.log(`   copied ${copied} static file(s) from public/`);
  }

  console.log('✅ App compiled successfully to dist/index.html');
}

compile();
