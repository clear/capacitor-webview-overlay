import { Component, ElementRef, ViewChild } from '@angular/core';
import { WebviewOverlay } from '@clear/capacitor-webview-overlay';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  title = 'example';

  @ViewChild("view")
  view?: ElementRef;

  handleClick() {
      let overlay = new WebviewOverlay(this.view?.nativeElement);
      overlay.init({ url: "https://google.com" });
  }
}
