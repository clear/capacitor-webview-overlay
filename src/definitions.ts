import { PluginListenerHandle } from '@capacitor/core';

export interface IWebviewOverlayPlugin {
    /**
     * Open a webview with the given URL
     */
    open(options: OpenOptions): Promise<{ id: string }>;

    /**
     * Close an open webview.
     */
    close(options: { id: string }): Promise<void>;

    /**
     * Load a url in the webview.
     */
    loadUrl(options: { id: string, url: string }): Promise<void>;

    /**
     * Get snapshot image
     */
    getSnapshot(options: { id: string }): Promise<{ src: string }>;

    show(options: { id: string }): Promise<void>;
    hide(options: { id: string }): Promise<void>;

    toggleFullscreen(options: { id: string }): Promise<void>;
    goBack(options: { id: string }): Promise<void>;
    goForward(options: { id: string }): Promise<void>;
    reload(options: { id: string }): Promise<void>;
    
    handleNavigationEvent(options: { id: string, allow: boolean }): Promise<void>;

    updateDimensions(options: { id: string, dimensions: Dimensions }): Promise<void>;

    evaluateJavaScript(options: { id: string, javascript: string }): Promise<{result: string}>;

    addListener(eventName: 'pageLoaded' | 'updateSnapshot' | 'progress' | string, listenerFunc: (...args: any[]) => void): PluginListenerHandle;
}

interface OpenOptions extends Dimensions {
    /**
     * The URL to open the webview to
     */
    url: string;

    javascript?: string;
    injectionTime?: ScriptInjectionTime;
}

interface Dimensions {
    width: number;
    height: number;
    x: number;
    y: number;
}

export enum ScriptInjectionTime {
    atDocumentStart,
    atDocumentEnd
}
