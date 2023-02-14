import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.example.webview_overlay',
  appName: 'example',
  webDir: 'dist/example',
  bundledWebRuntime: false,
  server: {
    url: 'http://localhost:4200',
    cleartext: true,
  },
};

export default config;
