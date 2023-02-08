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

  newViewButton() {
      this.openOverlay("https://google.com");
  }

  openOverlay(url: string) {
      let overlay = new WebviewOverlay(this.view?.nativeElement);
      overlay.init({ url });

      overlay.onPageLoaded(() => {
          console.log("Page loaded!");

          overlay.handleNavigation((e) => {
              console.log("Attempting to navigate to", e.url);

              let allow = confirm("Allow navigation to " + e.url);
              e.complete(allow);

              if (!allow) {
                  this.openOverlay(e.url);
              }
          })
      })

      this.overlays.push(overlay);
  }

  doneButton() {
      let overlay = this.overlays.pop();

      if (overlay) {
          overlay.close();
      }
  }
}
