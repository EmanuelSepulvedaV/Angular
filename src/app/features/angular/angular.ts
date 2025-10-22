import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { Components } from '../component/component';

@Component({
  selector: 'app-angular',
  imports: [CommonModule, Components],
  templateUrl: './angular.html',
  styleUrl: './angular.scss',
})
export class Angular {
  list = ['Emanuel', 'Sepulveda', 'Velez'];
  showList: boolean = false;

  onClick() {
    this.showList = !this.showList;
  }
  func(event: any) {
    console.log('event', event);
  }
}
