import { Component, ElementRef, ViewChild } from '@angular/core';
import { WebviewOverlay } from '@clear/capacitor-webview-overlay';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  @ViewChild("view")
  view?: ElementRef;

  overlays: WebviewOverlay[] = [];
  intervals: number[] = [];

  newViewButton() {
      this.openOverlay("https://google.com");
  }

  openOverlay(url: string) {
      let overlay = new WebviewOverlay(this.view?.nativeElement);
      overlay.init({ url });

      overlay.onPageLoaded(() => {
          console.log("Page loaded!");

          overlay.handleNavigation((e: any) => {
              console.log("Attempting to navigate to", e.url);

              let allow = confirm("Allow navigation to " + e.url);
              e.complete(allow);

              if (!allow) {
                  this.openOverlay(e.url);
              }
          })

          let interval = setInterval(async () => console.log(await overlay.evaluateJavaScript("document.title")), 1000) as unknown as number;
          this.intervals.push(interval);
      })

      this.overlays.push(overlay);
  }

  doneButton() {
      let overlay = this.overlays.pop();
      let interval = this.intervals.pop();
      clearInterval(interval);

      if (overlay) {
          overlay.close();
      }
  }
}
