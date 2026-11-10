import Foundation
@testable import Clipsmith

enum GoldenProjectFixture {
    static let json = #"""
{
  "bookmarks" : {

  },
  "library" : [
    {
      "durationInSeconds" : 30,
      "id" : "00000000-0000-0000-0000-000000000301",
      "kind" : "video",
      "url" : "file:\/\/\/Videos\/a.mov"
    }
  ],
  "project" : {
    "canvas" : "landscape",
    "id" : "00000000-0000-0000-0000-000000000001",
    "name" : "Golden",
    "tracks" : [
      {
        "clips" : [
          {
            "fadeInDurationInSeconds" : 0,
            "fadeOutDurationInSeconds" : 0,
            "id" : "00000000-0000-0000-0000-000000000202",
            "mediaKind" : "text",
            "sourceEndInSeconds" : 3,
            "sourceStartInSeconds" : 0,
            "startInSeconds" : 0,
            "textLayer" : {
              "color" : {
                "alpha" : 1,
                "blue" : 1,
                "green" : 1,
                "red" : 1
              },
              "content" : "Hi",
              "fontName" : "HelveticaNeue-Bold",
              "fontSize" : 72,
              "positionX" : 0.5,
              "positionY" : 0.85
            },
            "volume" : 1
          }
        ],
        "id" : "00000000-0000-0000-0000-000000000100",
        "role" : "text"
      },
      {
        "clips" : [

        ],
        "id" : "00000000-0000-0000-0000-000000000101",
        "role" : "broll"
      },
      {
        "clips" : [
          {
            "fadeInDurationInSeconds" : 1,
            "fadeOutDurationInSeconds" : 0,
            "id" : "00000000-0000-0000-0000-000000000201",
            "mediaKind" : "video",
            "sourceDurationInSeconds" : 30,
            "sourceEndInSeconds" : 6,
            "sourceStartInSeconds" : 2,
            "sourceURL" : "file:\/\/\/Videos\/a.mov",
            "startInSeconds" : 1,
            "volume" : 0.5
          }
        ],
        "id" : "00000000-0000-0000-0000-000000000102",
        "role" : "main"
      },
      {
        "clips" : [

        ],
        "id" : "00000000-0000-0000-0000-000000000103",
        "role" : "audio"
      }
    ]
  },
  "version" : 1
}
"""#

    static var expectedFile: ProjectFile {
        let url = URL(fileURLWithPath: "/Videos/a.mov")
        var project = Project(name: "Golden")
        project.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        for index in project.tracks.indices {
            project.tracks[index].id = UUID(uuidString: "00000000-0000-0000-0000-00000000010\(index)")!
        }
        var clip = Clip(
            sourceURL: url, mediaKind: .video, startInSeconds: 1, sourceStartInSeconds: 2,
            sourceEndInSeconds: 6, sourceDurationInSeconds: 30
        )
        clip.id = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        clip.volume = 0.5
        clip.fadeInDurationInSeconds = 1
        project.tracks[2].clips = [clip]
        var title = Clip(text: TextLayer(content: "Hi"), startInSeconds: 0, durationInSeconds: 3)
        title.id = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
        project.tracks[0].clips = [title]
        let item = MediaItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            url: url, kind: .video, durationInSeconds: 30
        )
        return ProjectFile(project: project, library: [item], bookmarks: [:])
    }
}
