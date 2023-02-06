import { PluginListenerHandle, registerPlugin } from '@capacitor/core';
import { IWebviewOverlayPlugin, ScriptInjectionTime } from './definitions';

import ResizeObserver from 'resize-observer-polyfill';

const WebviewOverlayPlugin = registerPlugin<IWebviewOverlayPlugin>('WebviewOverlayPlugin');

export interface WebviewOverlayOpenOptions {
    /**
     * The URL to open the webview to
     */
    url: string;

    script?: {
        javascript: string;
        injectionTime?: ScriptInjectionTime;
    }
}

export class WebviewOverlay {
    private updateSnapshotEvent: PluginListenerHandle;
    private pageLoadedEvent: PluginListenerHandle;
    private progressEvent: PluginListenerHandle;
    private navigationHandlerEvent: PluginListenerHandle;
    private resizeObserver: ResizeObserver;

    private id: string | null = null;

    constructor(private element: HTMLElement) {

    }

    async init(options: WebviewOverlayOpenOptions): Promise<void> {
        if (this.element && this.element.style) {
            this.element.style.backgroundSize = 'cover';
            this.element.style.backgroundRepeat = 'no-repeat';
            this.element.style.backgroundPosition = 'center';
        }

        const boundingBox = this.element.getBoundingClientRect() as DOMRect;

        let overlay = await WebviewOverlayPlugin.open({
            url: options.url,
            javascript: options.script ? options.script.javascript : '',
            injectionTime: options.script ? (options.script.injectionTime || ScriptInjectionTime.atDocumentStart) : ScriptInjectionTime.atDocumentStart,
            width: Math.round(boundingBox.width),
            height: Math.round(boundingBox.height),
            x: Math.round(boundingBox.x),
            y: Math.round(boundingBox.y)
        });
        this.id = overlay.id;

        this.updateSnapshotEvent = WebviewOverlayPlugin.addListener('updateSnapshot', () => {
            setTimeout(() => {
                this.toggleSnapshot(true);
            }, 100)
        });

        this.resizeObserver = new ResizeObserver((entries) => {
            for (const _entry of entries) {
                const boundingBox = this.element.getBoundingClientRect() as DOMRect;
                WebviewOverlayPlugin.updateDimensions({
                    id: overlay.id,
                    dimensions: {
                        width: Math.round(boundingBox.width),
                        height: Math.round(boundingBox.height),
                        x: Math.round(boundingBox.x),
                        y: Math.round(boundingBox.y)
                    }
                });
            }
        });

        this.resizeObserver.observe(this.element);
    }

    close(): Promise<void> {
        this.element = null;

        this.resizeObserver.disconnect();

        this.updateSnapshotEvent?.remove();
        this.pageLoadedEvent?.remove();
        this.progressEvent?.remove();
        this.navigationHandlerEvent?.remove();

        return WebviewOverlayPlugin.close({ id: this.id });
    }

    async toggleSnapshot(snapshotVisible: boolean): Promise<void> {
        return new Promise<void>(async (resolve) => {
            const snapshot = (await WebviewOverlayPlugin.getSnapshot({ id: this.id })).src;
            if (snapshotVisible) {
                if (snapshot) {
                    const buffer = await (await fetch('data:image/jpeg;base64,' + snapshot)).arrayBuffer();
                    const blob = new Blob([buffer], { type: 'image/jpeg' });
                    const blobUrl = URL.createObjectURL(blob);
                    const img = new Image();
                    img.onload = async () => {
                        if (this.element && this.element.style) {
                            this.element.style.backgroundImage = `url(${blobUrl})`;
                        }
                        setTimeout(async () => {
                            await WebviewOverlayPlugin.hide({ id: this.id });
                            resolve();
                        }, 25)
                    };
                    img.src = blobUrl;
                }
                else {
                    if (this.element && this.element.style) {
                        this.element.style.backgroundImage = `none`;
                    }
                    await WebviewOverlayPlugin.hide({ id: this.id });
                    resolve();
                }
            }
            else {
                if (this.element && this.element.style) {
                    this.element.style.backgroundImage = `none`;
                }
                await WebviewOverlayPlugin.show({ id: this.id });
                resolve();
            }
        });
    }

    async evaluateJavaScript(javascript: string): Promise<string> {
        return (await WebviewOverlayPlugin.evaluateJavaScript({
            id: this.id,
            javascript
        })).result;
    }

    // TODO: Listen for matching ID
    onPageLoaded(listenerFunc: () => void) {
        this.pageLoadedEvent = WebviewOverlayPlugin.addListener('pageLoaded', listenerFunc);
    }
    onProgress(listenerFunc: (progress: { value: number }) => void) {
        this.progressEvent = WebviewOverlayPlugin.addListener('progress', listenerFunc);
    }

    handleNavigation(listenerFunc: (event: {
        url: string,
        newWindow: boolean,
        sameHost: boolean,
        complete: (allow: boolean) => void
    }) => void) {
        this.navigationHandlerEvent = WebviewOverlayPlugin.addListener('navigationHandler', (event: any) => {
            const complete = (allow: boolean) => {
                WebviewOverlayPlugin.handleNavigationEvent({ id: this.id, allow });
            }
            listenerFunc({ ...event, complete });
        });
    }

    toggleFullscreen() {
        WebviewOverlayPlugin.toggleFullscreen({ id: this.id });
    }

    goBack() {
        WebviewOverlayPlugin.goBack({ id: this.id });
    }

    goForward() {
        WebviewOverlayPlugin.goForward({ id: this.id });
    }

    reload() {
        WebviewOverlayPlugin.reload({ id: this.id });
    }

    loadUrl(url: string) {
        return WebviewOverlayPlugin.loadUrl({ id: this.id, url });
    }

}

