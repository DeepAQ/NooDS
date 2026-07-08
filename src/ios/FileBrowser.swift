/*
    Copyright 2019-2025 Hydr8gon

    This file is part of NooDS.

    NooDS is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    NooDS is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with NooDS. If not, see <https://www.gnu.org/licenses/>.
*/

import SwiftUI

struct FileRow: View {
    let name: String
    let icon: Image

    init(path: String, name: String, folder: Bool) {
        // Set the name and icon for a file row
        self.name = name
        if !folder && name.hasSuffix(".nds") {
            // Use an icon extracted from a .nds file
            var ndsIcon = NdsIcon(path + "/" + name)
            let space = CGColorSpaceCreateDeviceRGB()
            let info = CGBitmapInfo(alpha: .noneSkipLast, component: .integer, byteOrder: .orderDefault)
            let prov = CGDataProvider(data: CFDataCreate(nil, ndsIcon.getIcon(), 32 * 32 * 4)!)!
            let deco = CGImage(width: 32, height: 32, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: 32 * 4, space: space, bitmapInfo: info, provider: prov,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
            icon = Image(decorative: deco, scale: 1.0, orientation: .up).resizable()
        }
        else {
            // Use a generic file or folder icon
            icon = Image(folder ? "Folder" : "File").resizable()
                .renderingMode(.template)
        }
    }

    var body: some View {
        // List a file/folder with an icon and name
        HStack {
            icon.frame(width: 40, height: 40)
            Text(name)
            Spacer()
        }
        .foregroundColor(.primary)
    }
}

struct FileBrowser: View {
    @Binding var running: Bool
    @Binding var ndsPath: String
    @Binding var gbaPath: String
    @State var curPath: String
    @State var contents: [String]
    let manager = FileManager.default
    let base: String

    @State var dualRoms = false
    @State var askGba = false
    @State var showError = false
    @State var errorType = 0 as CInt

    init(running: Binding<Bool>, ndsPath: Binding<String>, gbaPath: Binding<String>) {
        // Initialize values for the base directory
        let docsUrl = manager.urls(for: .documentDirectory, in: .userDomainMask).first!
        _running = running
        _ndsPath = ndsPath
        _gbaPath = gbaPath
        curPath = docsUrl.path
        contents = try! manager.contentsOfDirectory(atPath: docsUrl.path).sorted()
        base = docsUrl.path
    }

    var body: some View {
        NavigationView {
            List {
                // Add a parent directory listing when outside the base
                if curPath != base {
                    Button {
                        // Navigate to the parent directory
                        curPath = String(curPath[..<curPath.lastIndex(of: "/")!])
                        contents = try! manager.contentsOfDirectory(atPath: curPath).sorted()
                    }
                    label: {
                        FileRow(path: curPath, name: "..", folder: true)
                    }
                }

                // List all folders and ROMs at the current directory
                ForEach(contents, id: \.self) { content in
                    var isDir = false as ObjCBool
                    let folder = manager.fileExists(atPath: curPath + "/" + content, isDirectory: &isDir) && isDir.boolValue
                    if folder || content.hasSuffix(".nds") || content.hasSuffix(".gba") {
                        Button {
                            // Handle item selection based on type
                            if folder {
                                // Navigate to the selected folder
                                curPath += "/" + content
                                contents = try! manager.contentsOfDirectory(atPath: curPath).sorted()
                            }
                            else if content.hasSuffix(".nds") {
                                // Load a NDS ROM by itself or ask to load alongside a GBA ROM
                                ndsPath = curPath + "/" + content
                                if gbaPath.isEmpty {
                                    loadRom()
                                }
                                else {
                                    askGba = true
                                    dualRoms = true
                                }
                            }
                            else {
                                // Load a GBA ROM by itself or ask to load alongside a NDS ROM
                                gbaPath = curPath + "/" + content
                                if ndsPath.isEmpty {
                                    loadRom()
                                }
                                else {
                                    askGba = false
                                    dualRoms = true
                                }
                            }
                        }
                        label: {
                            FileRow(path: curPath, name: content, folder: folder)
                        }
                    }
                }
            }
            .navigationTitle("NooDS")
            .toolbar {
                // Link to the settings menu in the toolbar
                NavigationLink {
                    SettingsMenu()
                }
                label: {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
        .overlay(EmptyView().alert(isPresented: $dualRoms) {
            // Show an alert asking if two ROMs should be loaded at once
            if askGba {
                Alert(title: Text("Loading NDS ROM"), message: Text("Load the previous GBA ROM alongside this ROM?"),
                    primaryButton: .default(Text("Yes"), action: {
                        loadRom()
                    }),
                    secondaryButton: .default(Text("No"), action: {
                        gbaPath = String()
                        loadRom()
                    }))
            }
            else {
                Alert(title: Text("Loading GBA ROM"), message: Text("Load the previous NDS ROM alongside this ROM?"),
                    primaryButton: .default(Text("Yes"), action: {
                        loadRom()
                    }),
                    secondaryButton: .default(Text("No"), action: {
                        ndsPath = String()
                        loadRom()
                    }))
            }
        })
        .overlay(EmptyView().alert(isPresented: $showError) {
            // Show an alert explaining the type of error encountered
            switch (errorType) {
            case 1:
                Alert(title: Text("Error Loading BIOS"), message: Text("Make sure the path settings point" +
                    " to valid BIOS files and try again. You can modify path settings in noods/noods.ini."))
            case 2:
                Alert(title: Text("Error Loading Firmware"), message:
                    Text("Make sure the path settings point to a bootable firmware file or try" +
                    " another boot method. You can modify path settings in noods/noods.ini."))
            default:
                Alert(title: Text("Error Loading ROM"), message:
                    Text("Make sure the ROM file is accessible and try again."))
            }
        })
    }

    func loadRom() -> Void {
        // Load a ROM or show an error if failed
        let type = CoreBridge.loadRom(ndsPath, gbaPath)
        if type == 0 {
            running = true
        }
        else {
            ndsPath = String()
            gbaPath = String()
            errorType = type
            showError = true
        }
    }
}
