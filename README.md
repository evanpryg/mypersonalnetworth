# My Networth & Money Management Tracker

A personal finance tracker and portfolio management tool migrated from Google Sheets to a serverless architecture using **Supabase** as the database and hosted on **GitHub Pages**.

---

## 🚀 Features

- **Double Workspace**: Investment Portfolio Tracker + Money Management (Daily Transaction Budgeting).
- **Supabase Backend**: Fully serverless, querying your personal database directly from the browser.
- **Client-Side Security**: Your database connection keys (URL & Anon Key) are saved locally in your browser's `localStorage` and never committed to GitHub or sent to any third party.
- **Automatic GitHub Pages Deployment**: Push code to the `main` branch, and a GitHub Action automatically compiles and deploys the app to the live URL.

---

## 🛠️ Step 1: Supabase Setup (Database)

1. Create a free account at [Supabase](https://supabase.com).
2. Create a new project (e.g., `my-networth`).
3. Once the database is ready, go to the **SQL Editor** tab from the left sidebar.
4. Click **New query**, paste the entire contents of the [supabase_schema.sql](supabase_schema.sql) file, and click **Run**.
   - This creates all 9 tables (matching your old spreadsheets) with preloaded default settings and optimization indexes.

---

## 📥 Step 2: Import Your Old Data (CSV)

If you have old data from Google Sheets, export each sheet as a `.csv` file and import it directly into Supabase:

1. In Supabase, go to the **Table Editor** page.
2. Select one of the tables (e.g. `Transactions`).
3. Click the **Insert** button at the top and select **Import data from CSV**.
4. Drag and drop your exported CSV file.
   - The headers in your CSV match the double-quoted table columns exactly (`Timestamp`, `Date`, `Platform`, `AmountIDR`, etc.), so Supabase will automatically map them without any manual intervention!
5. Click **Import Data** to load your history. Repeat for other tables like `MM_Transactions` if needed.

---

## 🌐 Step 3: Hosting on GitHub Pages

1. Create a new **public** repository on GitHub.
2. Initialize git and push this codebase to the repository:
   ```bash
   git init
   git add .
   git commit -m "Initial commit with Supabase integration"
   git branch -M main
   git remote add origin https://github.com/your-username/your-repo-name.git
   git push -u origin main
   ```
3. Once pushed, the **GitHub Actions** workflow will automatically compile the application and push the static bundle to a new branch called `gh-pages`.
4. Go to your repository settings on GitHub:
   - Scroll down to **Pages** in the left sidebar.
   - Under **Build and deployment**, select **Deploy from a branch**.
   - Change the branch from `none` to **`gh-pages`** and keep the folder as `/ (root)`.
   - Click **Save**.
5. Wait 1-2 minutes, and your site will be live at:
   `https://your-username.github.io/your-repo-name/`

---

## ⚡ Step 4: Connecting the App

1. Open your live GitHub Pages URL.
2. On the first load, a setup screen will ask you for your **Supabase Project URL** and **Anon Key**.
   - You can find these in Supabase under **Project Settings** → **API**.
3. Click **Connect & Sync App**.
4. The app will verify connection, load your imported data, and you're good to go!
5. If you ever need to change your database connection, go to the **Settings** page inside the app and look for the **Supabase Connection** panel.

---

## 💻 Local Development

To run the app locally:
1. Ensure you have [Node.js](https://nodejs.org) installed.
2. Build the production HTML:
   ```bash
   node build.js
   ```
3. Open `dist/index.html` directly in your browser or serve it using a local server extension.
