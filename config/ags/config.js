import { Bar } from './bar.js'
import { NotificationPopups } from './notificationPopups.js'

App.config({
    windows: [Bar(0), NotificationPopups()],
    style: './style.css',
})
