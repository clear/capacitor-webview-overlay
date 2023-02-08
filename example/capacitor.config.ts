import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.example.webview_overlay',
  appName: 'example',
  webDir: 'dist/example',
  bundledWebRuntime: false,
  server: {
    url: 'http://10.11.254.71:4200',
    cleartext: true,
  },
};

export default config;
