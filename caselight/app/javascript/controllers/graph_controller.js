import { Controller } from "@hotwired/stimulus"

// Citing-references graph: deterministic radial layout, treatment-colored
// edges (green/amber/red), node size by depth of treatment.
export default class extends Controller {
  static values = { url: String }
  static targets = ["canvas", "tooltip"]

  COLORS = { positive: "#16a34a", cautionary: "#d97706", negative: "#dc2626" }

  async connect() {
    const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
    if (!response.ok) return
    this.draw(await response.json())
  }

  draw({ center, nodes }) {
    const W = this.canvasTarget.clientWidth || 760
    const H = 480
    const cx = W / 2, cy = H / 2
    const svgNS = "http://www.w3.org/2000/svg"
    const svg = document.createElementNS(svgNS, "svg")
    svg.setAttribute("viewBox", `0 0 ${W} ${H}`)
    svg.setAttribute("class", "w-full")
    svg.setAttribute("role", "img")
    svg.setAttribute("aria-label", `Citation graph: ${nodes.length} citing cases for ${center.title}`)

    const years = nodes.map((n) => n.year).filter(Boolean)
    const minYear = Math.min(...years, new Date().getFullYear() - 1)
    const maxYear = Math.max(...years, new Date().getFullYear())

    nodes.forEach((node, i) => {
      const angle = (i / nodes.length) * Math.PI * 2 - Math.PI / 2
      const spread = node.year ? (node.year - minYear) / Math.max(maxYear - minYear, 1) : 0.5
      const radius = 90 + spread * (Math.min(W, H) / 2 - 120)
      const x = cx + Math.cos(angle) * radius
      const y = cy + Math.sin(angle) * radius
      const color = this.COLORS[node.classification] || "#64748b"

      const edge = document.createElementNS(svgNS, "line")
      edge.setAttribute("x1", x); edge.setAttribute("y1", y)
      edge.setAttribute("x2", cx); edge.setAttribute("y2", cy)
      edge.setAttribute("stroke", color)
      edge.setAttribute("stroke-opacity", "0.45")
      edge.setAttribute("stroke-width", "1.2")
      svg.appendChild(edge)

      const size = 4 + ({ passing: 0, discussed: 2, significant: 4, extended: 6 }[node.depth] ?? 0)
      const link = document.createElementNS(svgNS, "a")
      link.setAttribute("href", node.url)
      const dot = document.createElementNS(svgNS, "circle")
      dot.setAttribute("cx", x); dot.setAttribute("cy", y); dot.setAttribute("r", size)
      dot.setAttribute("fill", color)
      dot.setAttribute("tabindex", "0")
      dot.addEventListener("mouseenter", () => this.showTip(node, x, y, W))
      dot.addEventListener("focus", () => this.showTip(node, x, y, W))
      dot.addEventListener("mouseleave", () => this.hideTip())
      dot.addEventListener("blur", () => this.hideTip())
      const title = document.createElementNS(svgNS, "title")
      title.textContent = `${node.title} — ${node.treatment} (${node.year ?? "n.d."})`
      dot.appendChild(title)
      link.appendChild(dot)
      svg.appendChild(link)
    })

    const hub = document.createElementNS(svgNS, "circle")
    hub.setAttribute("cx", cx); hub.setAttribute("cy", cy); hub.setAttribute("r", 13)
    hub.setAttribute("fill", "#b43719")
    svg.appendChild(hub)
    const label = document.createElementNS(svgNS, "text")
    label.setAttribute("x", cx); label.setAttribute("y", cy + 30)
    label.setAttribute("text-anchor", "middle")
    label.setAttribute("class", "fill-gray-700 text-[11px] font-semibold")
    label.textContent = center.citation || center.title
    svg.appendChild(label)

    this.canvasTarget.replaceChildren(svg)
  }

  showTip(node, x, y, w) {
    if (!this.hasTooltipTarget) return
    this.tooltipTarget.innerHTML =
      `<span class="font-semibold">${node.title}</span><br>${node.citation ?? ""} · ${node.treatment.replaceAll("_", " ")} · ${node.year ?? "n.d."}`
    this.tooltipTarget.style.left = `${Math.min(x, w - 220)}px`
    this.tooltipTarget.style.top = `${y + 14}px`
    this.tooltipTarget.classList.remove("hidden")
  }

  hideTip() {
    if (this.hasTooltipTarget) this.tooltipTarget.classList.add("hidden")
  }
}
