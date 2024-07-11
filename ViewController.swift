import UIKit
import MapKit
import CoreLocation
import CoreData


class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var commentText: UITextField!
    @IBOutlet weak var nameText: UITextField!
    
    var locationManager = CLLocationManager()                     // kullanıcının konumunu alma
    var chosenLatitude = Double()
    var chosenLongitude = Double()
    
    var selectedTitle = ""
    var selecetedTitleId : UUID?
    
    var annotationTitle = ""
    var annotationSubtitle = ""
    var annotationLatitude = Double()
    var annotationLongitude = Double()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        locationManager.delegate = self
        mapView.isUserInteractionEnabled = true
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // konumun verisi ne kadar keskinlikle buluncak
        locationManager.requestWhenInUseAuthorization()          // konumu kullanmak için kullanıcıdan izin istiyoruz
        locationManager.startUpdatingLocation()
        
        
        // Pinleme
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(choseLocation(gestureRecognizer:))) // uzun basılınca çıkıcak
        gestureRecognizer.minimumPressDuration = 3.0            // ne kadar sn basılmalı
        mapView.addGestureRecognizer(gestureRecognizer)
        
        if selectedTitle != "" {
            // core data'dan çekecez
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Places")
            let idString = selecetedTitleId!.uuidString
            fetchRequest.predicate = NSPredicate(format: "id = %@", idString)
            fetchRequest.returnsObjectsAsFaults = false
            
            do{
                let results = try context.fetch(fetchRequest)
                
                if results.count > 0 {
                    for result in results as! [NSManagedObject]{
                        
                        if let title = result.value(forKey: "title") as? String{
                            annotationTitle = title
                        }
                        
                        if let subtitle = result.value(forKey: "subtitle") as? String{
                            annotationSubtitle = subtitle
                        }
                        
                        if let latitude = result.value(forKey: "latitude") as? Double{
                            annotationLatitude = latitude
                        }
                        
                        if let longitude = result.value(forKey: "longitude") as? Double{
                            annotationLongitude = longitude
                        }
                        
                        let annotation = MKPointAnnotation()
                        annotation.title = annotationTitle
                        annotation.subtitle = annotationSubtitle
                        
                        let coordinate = CLLocationCoordinate2D(latitude: annotationLatitude, longitude: annotationLongitude)
                        annotation.coordinate = coordinate
                        
                        mapView.addAnnotation(annotation)
                        nameText.text = annotationTitle
                        commentText.text = annotationSubtitle
                        
                        locationManager.stopUpdatingLocation()
                        
                        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        let region = MKCoordinateRegion(center: coordinate, span: span)
                        
                        mapView.setRegion(region, animated: true)
                    }
                }
            }catch{
                print("Error!")
            }
            
        } else {
            // Add new data
        }
    }

    @objc func choseLocation(gestureRecognizer:UILongPressGestureRecognizer){
        
        if gestureRecognizer.state != .began {
            let touchPoint = gestureRecognizer.location(in: self.mapView)
            let touchedCoordinates = self.mapView.convert(touchPoint, toCoordinateFrom: self.mapView)       // dokunulan koordinatları verecek
            
            chosenLatitude = touchedCoordinates.latitude
            chosenLongitude = touchedCoordinates.longitude
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = touchedCoordinates
           
            annotation.title = nameText.text
            annotation.subtitle = commentText.text
            self.mapView.addAnnotation(annotation)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {     // güncellenen konumları dizi içerisinde veriyor
        
        if selectedTitle == "" {
            let location = CLLocationCoordinate2D(latitude: locations[0].coordinate.latitude, longitude: locations[0].coordinate.longitude) // enlem ve boylamlar
            let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1) // zoomlanacak
            let region = MKCoordinateRegion(center: location, span: span)
            self.mapView.setRegion(region, animated: true)
        }else{
            //
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        
        if annotation is MKUserLocation{
            return nil
        }
        
        let reuseID = "myAnnotation"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKMarkerAnnotationView
        
        if pinView == nil {
            pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            pinView?.canShowCallout = true
            pinView?.tintColor = UIColor.green
            
            let button = UIButton(type: UIButton.ButtonType.detailDisclosure)
            pinView?.rightCalloutAccessoryView = button
        }else{
            pinView?.annotation = annotation
        }
        
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if selectedTitle != "" {
            let requestLocation = CLLocation(latitude: annotationLatitude, longitude: annotationLongitude)
            
            CLGeocoder().reverseGeocodeLocation(requestLocation) { [self] placemarks, error in
                // closure
                if let placemark = placemarks{
                    if placemark.count > 0 {
                        let newPlacemark = MKPlacemark(placemark: placemark[0])
                        let item = MKMapItem(placemark: newPlacemark)
                        item.name = self.annotationTitle
                        
                        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
                        item.openInMaps(launchOptions: launchOptions)
                    }
                }
            }
        }
    }
    
    @IBAction func saveButtonClicked(_ sender: Any) {
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let newPlace = NSEntityDescription.insertNewObject(forEntityName: "Places", into: context)
        
        newPlace.setValue(nameText.text, forKey: "title")
        newPlace.setValue(commentText.text, forKey: "subtitle")
        newPlace.setValue(chosenLatitude, forKey: "latitude")
        newPlace.setValue(chosenLongitude, forKey: "longitude")
        newPlace.setValue(UUID(), forKey: "id")
        
        do{
            try context.save()
            print("Success!")
        }catch{
            print("Error!")
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("newPlace"), object: nil)
        navigationController?.popViewController(animated: true)
    }
}
