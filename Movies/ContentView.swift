//
//  ContentView.swift
//  Movies
//
//  Created by Rodrigo Leyva on 4/24/20.
//  Copyright © 2020 Rodrigo Leyva. All rights reserved.
//

import SwiftUI
import SDWebImageSwiftUI
import Grid

struct ContentView: View {
    
    var body: some View{
        TabView{
            PopularView().tabItem{
                Image(systemName: "house.fill")
                Text("Popular")
            }
            TopRatedView().tabItem{
                Image(systemName: "heart.fill")
                Text("Top Rated")
            }
            UpcomingView().tabItem{
                Image(systemName: "hand.thumbsup.fill")
                Text("Upcoming")
            }

        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct UpcomingView:View {
    var body: some View{
            Text("Upcoming Movies").font(.largeTitle)
    }
}

struct TopRatedView:View {
    
    
    var body: some View{
            Text("Top rated").font(.largeTitle)
          
    }
}


struct PopularView: View {
    @State var pages_loaded = 0
    @ObservedObject var getData = PopularMovieData()
    @State var showMovieDetail = false
    @State var selected_index = 0
    var baseImageURL = "https://image.tmdb.org/t/p/w1280"
    
    
    var body: some View {
        
        VStack(alignment:.leading) {
            NavigationView{
                List(getData.jsonData){(movie:Movie) in
                    Button(action:{self.showMovieDetail.toggle()}){
                        MovieCardView(image_path: movie.poster_path ?? "")
                                .onAppear{
                                    self.getData.loadMoreData(currentItem: movie)
                        }
                    }.sheet(isPresented: self.$showMovieDetail) {
                                MovieDetailView(movie: movie)
                            }
                        .navigationBarTitle(Text("Popular Movies"))
                    }
                    
                }
            }
            
        }
    }

                    
            


struct MovieDetailView:View {
    var movie: Movie
    var baseImageURL = "https://image.tmdb.org/t/p/w1280"

    var body: some View{
        ZStack {
            VStack{
                AnimatedImage(url:URL(string: baseImageURL + (movie.backdrop_path ?? "") ))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity,minHeight: 0,maxHeight: UIScreen.main.bounds.height/3)
                            .edgesIgnoringSafeArea(.top)
                Spacer()
                VStack(alignment:.center,spacing: 10){
                    Text("Overview").font(.system(size: 25))

                    Text(movie.overview).font(.system(size: 15))
                        .fontWeight(.light)
                        .foregroundColor(.primary)
                    Text("Rating:")
                        .font(.system(size: 20))
                        .fontWeight(.light)
                    HStack{
                        Spacer()
                        ForEach(0..<Int(movie.vote_average.floor(nearest: 1.0))){i in
                            Image(systemName: "star.fill").font(.system(size:30,weight:.ultraLight))
                                .foregroundColor(Color.yellow)
                        }
                        if Int(movie.vote_average.floor(nearest: 1.0)) == 0{
                            Text("No Rating").font(.system(size: 30)).fontWeight(.ultraLight)
                        }
                        if movie.vote_average > (movie.vote_average.floor(nearest: 1.0) + 0.5){
                            Image(systemName: "star.lefthalf.fill")
                                .font(.system(size:30,weight:.ultraLight)).foregroundColor(Color.yellow)
                        }
                        Spacer()
                        
                    }.padding(.vertical)
                }.padding()
                }
            MovieCardView(image_path: movie.poster_path!)
            .offset(y: -125)
            
           
    
        }
        
        
    }
}
extension Double{
    func round(nearest: Double)-> Double{
        let n = 1/nearest
        let numberToRound = self * n
        return numberToRound.rounded() / n
    }
    func floor(nearest: Double) -> Double {
        let intDiv = Double(Int(self / nearest))
        return intDiv * nearest
    }
}
//
struct MovieCardView: View {
   var image_path : String
   var baseImageURL = "https://image.tmdb.org/t/p/w1280"


    var body: some View{
        VStack(alignment:.center) {
            HStack {
                Spacer()
                AnimatedImage(url:URL(string: baseImageURL + image_path))
                .resizable()
                .frame(width: UIScreen.main.bounds.width/1.2, height: UIScreen.main.bounds.height/2, alignment: .center)
                .cornerRadius(20)
                    .shadow(radius: 35)
                Spacer()
            }
            
        }
    }
}



class PopularMovieData: ObservableObject,RandomAccessCollection {
    typealias Element = Movie

    //var next_page = 1
    @Published var jsonData = [Movie]()
    var startIndex: Int { jsonData.startIndex }
    var endIndex: Int { jsonData.endIndex }
    var loadStatus = LoadStatus.ready(nextPage: 1)

    var urlBase = "https://api.themoviedb.org/3/movie/popular?api_key=9d1758e1f320da5cf259e86ac05578db&language=en-US&page="
    
    init() {
        loadMoreData()
    }
    subscript(position: Int) -> Movie {
        return jsonData[position]
    }
    func loadMoreData(currentItem: Movie? = nil){
        if !shouldLoadMoreData(currentItem: currentItem){
            return
        }
        guard case let .ready(page) = loadStatus else {
            return
        }
        loadStatus = .loading(page: page)
        
        let urlString = "\(urlBase)\(page)"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { (data, url, error) in
            guard error == nil else {
                print("Error: \(error!)")
                self.loadStatus = .parseError
                return
            }
            guard let data = data else {
                print("No Data")
                self.loadStatus = .parseError

                return
            }
            
            let movies = self.parseJsonFromData(data: data)
            DispatchQueue.main.async {
                self.jsonData.append(contentsOf: movies)
                if movies.count == 0{
                    self.loadStatus = .done
                }else{
                    guard case let .loading(page) = self.loadStatus else {
                        fatalError("loadSatus is in a bad state")
                    }
                    self.loadStatus = .ready(nextPage: page + 1)
                }
            }
        }
        task.resume()
    }
    func shouldLoadMoreData(currentItem: Movie? = nil)-> Bool{
        
        guard let currentItem = currentItem else {
            return true
        }
        for n in (self.jsonData.count - 4)...(self.jsonData.count-1) {
            if n >= 0 && currentItem.id == self.jsonData[n].id {
                return true
            }
        }
        
        return false
    }
    func parseJsonFromData(data: Data)->[Movie]{
        var response : JsonResponse
        do {
            response = try JSONDecoder().decode(JsonResponse.self, from: data)
        }
        catch {
            print("Error parsing the JSON: \(error)")
            return []
        }
        return response.results ?? []
    }
    enum LoadStatus {
        case ready (nextPage: Int)
        case loading (page: Int)
        case parseError
        case done
    }
    
        
}

struct datatype: Identifiable, Codable {
    var id : Int
    var login: String
    var avatar_url : String
}

struct JsonResponse: Codable,Hashable {
    var page: Int
    var results : [Movie]
}
struct Movie: Identifiable,Codable,Hashable {
    var id: Int
    var poster_path: String?
    var title: String
    var overview: String
    var vote_average: Double
    var backdrop_path : String?
}

