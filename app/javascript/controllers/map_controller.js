import L from "leaflet"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.map = L.map(this.element)

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(this.map)

    this.addMarkers(JSON.parse(this.element.dataset.mapMarkers || "[]"))
  }

  addMarkers(markers) {
    markers.forEach((marker) => {
      L.marker([marker.lat, marker.lng]).addTo(this.map).bindPopup(this.popupFor(marker))
    })

    if (markers.length === 1) {
      this.map.setView([markers[0].lat, markers[0].lng], 13)
    } else if (markers.length > 1) {
      const bounds = L.latLngBounds(markers.map((marker) => [marker.lat, marker.lng]))
      this.map.fitBounds(bounds.pad(0.2))
    } else {
      this.map.setView([20, 0], 2)
    }
  }

  // Builds the popup with DOM APIs so user-authored titles are never treated as HTML.
  popupFor(marker) {
    const container = document.createElement("div")
    const link = document.createElement("a")
    link.href = marker.url
    link.textContent = marker.title
    container.appendChild(link)

    const meta = document.createElement("div")
    meta.className = "meta"
    meta.textContent = [marker.location_name, marker.date].filter(Boolean).join(" · ")
    container.appendChild(meta)

    return container
  }
}
