import CarPlay

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                   didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let template = buildDashboard()
        interfaceController.setRootTemplate(template, animated: false)
    }

    private func buildDashboard() -> CPInformationTemplate {
        let speedItem = CPInformationItem(
            title: NSLocalizedString("carplay.speed", comment: ""),
            detail: "0 km/h"
        )
        let distanceItem = CPInformationItem(
            title: NSLocalizedString("carplay.distance", comment: ""),
            detail: "0.0 km"
        )
        return CPInformationTemplate(
            title: "FaisTrack",
            layout: .leading,
            items: [speedItem, distanceItem],
            actions: []
        )
    }
}
