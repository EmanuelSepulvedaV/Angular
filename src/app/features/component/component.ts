import { Component, EventEmitter, Output } from '@angular/core';

@Component({
  selector: 'app-component',
  imports: [],
  templateUrl: './component.html',
  styleUrl: './component.scss',
})
export class Components {
  @Output() emitData = new EventEmitter();
}
