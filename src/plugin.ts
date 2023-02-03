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

    /**
     * The element to open the webview in place of. The webview will open with the same dimensions and fixed position on screen.
     * When toggled off, the element will have a background image with the webview snapshot.
     */
    element: HTMLElement;
}

class WebviewOverlayClass {

    element: HTMLElement;
    updateSnapshotEvent: PluginListenerHandle;
    pageLoadedEvent: PluginListenerHandle;
    progressEvent: PluginListenerHandle;
    navigationHandlerEvent: PluginListenerHandle;
    resizeObserver: ResizeObserver;

    async open(options: WebviewOverlayOpenOptions): Promise<string> {
        this.element = options.element;

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

        this.updateSnapshotEvent = WebviewOverlayPlugin.addListener('updateSnapshot', () => {
            setTimeout(() => {
                this.toggleSnapshot(overlay.id, true);
            }, 100)
        });

        this.resizeObserver = new ResizeObserver((entries) => {
            for (const _entry of entries) {
                const boundingBox = options.element.getBoundingClientRect() as DOMRect;
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

        return overlay.id;
    }

    close(id: string): Promise<void> {
        this.element = undefined;
        this.resizeObserver.disconnect();
        if (this.updateSnapshotEvent) {
            this.updateSnapshotEvent.remove();
        }
        if (this.pageLoadedEvent) {
            this.pageLoadedEvent.remove();
        }
        if (this.progressEvent) {
            this.progressEvent.remove();
        }
        if (this.navigationHandlerEvent) {
            this.navigationHandlerEvent.remove();
        }
        return WebviewOverlayPlugin.close({ id });
    }

    async toggleSnapshot(id: string, snapshotVisible: boolean): Promise<void> {
        return new Promise<void>(async (resolve) => {
            const snapshot = (await WebviewOverlayPlugin.getSnapshot({ id })).src;
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
                            await WebviewOverlayPlugin.hide({ id });
                            resolve();
                        }, 25)
                    };
                    img.src = blobUrl;
                }
                else {
                    if (this.element && this.element.style) {
                        this.element.style.backgroundImage = `none`;
                    }
                    await WebviewOverlayPlugin.hide({ id });
                    resolve();
                }
            }
            else {
                if (this.element && this.element.style) {
                    this.element.style.backgroundImage = `none`;
                }
                await WebviewOverlayPlugin.show({ id });
                resolve();
            }
        });
    }

    async evaluateJavaScript(id: string, javascript: string): Promise<string> {
        return (await WebviewOverlayPlugin.evaluateJavaScript({
            id,
            javascript
        })).result;
    }

    onPageLoaded(listenerFunc: () => void) {
        this.pageLoadedEvent = WebviewOverlayPlugin.addListener('pageLoaded', listenerFunc);
    }

    onProgress(listenerFunc: (progress: { value: number }) => void) {
        this.progressEvent = WebviewOverlayPlugin.addListener('progress', listenerFunc);
    }

    handleNavigation(id: string, listenerFunc: (event: {
        url: string,
        newWindow: boolean,
        sameHost: boolean,
        complete: (allow: boolean) => void
    }) => void) {
        this.navigationHandlerEvent = WebviewOverlayPlugin.addListener('navigationHandler', (event: any) => {
            const complete = (allow: boolean) => {
                WebviewOverlayPlugin.handleNavigationEvent({ id, allow });
            }
            listenerFunc({ ...event, complete });
        });
    }

    toggleFullscreen(id: string) {
        WebviewOverlayPlugin.toggleFullscreen({ id });
    }

    goBack(id: string) {
        WebviewOverlayPlugin.goBack({ id });
    }

    goForward(id: string) {
        WebviewOverlayPlugin.goForward({ id });
    }

    reload(id: string) {
        WebviewOverlayPlugin.reload({ id });
    }

    loadUrl(id: string, url: string) {
        return WebviewOverlayPlugin.loadUrl({ id, url });
    }

}

export const WebviewOverlay = new WebviewOverlayClass();
