const { app, BrowserWindow, session, Menu } = require('electron');
const path = require('path');

const URL = 'https://10.130.70.55';

let mainWindow = null;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 900,
    minHeight: 600,
    title: 'NeonChat',
    icon: path.join(__dirname, 'icon.png'),
    backgroundColor: '#27292d',
    autoHideMenuBar: true,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      webSecurity: true
    }
  });

  // Ignoră eroarea certificatului self-signed
  session.defaultSession.setCertificateVerifyProc((request, callback) => {
    console.log('[CERT] Ignorat pentru:', request.hostname);
    callback(0); // 0 = acceptă
  });

  // Permite notificări
  session.defaultSession.setPermissionRequestHandler((webContents, permission, callback) => {
    console.log('[PERM] Cerere:', permission);
    callback(true);
  });

  // Încarcă URL-ul
  mainWindow.loadURL(URL).catch(err => {
    console.error('Eroare la încărcare:', err);
  });

  // Deschide link-urile externe în browser
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (!url.startsWith(URL)) {
      require('electron').shell.openExternal(url);
      return { action: 'deny' };
    }
    return { action: 'allow' };
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  console.log('[APP] Fereastră creată, încarc:', URL);
}

// Meniu minimal
Menu.setApplicationMenu(null);

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
