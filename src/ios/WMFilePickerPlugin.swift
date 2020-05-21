/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

import Foundation
import Photos
import UIKit
import MobileCoreServices

private let IMAGE = "IMAGE";
private let VIDEO = "VIDEO";
private let AUDIO = "AUDIO";
private let FILE = "FILE";

public class WMFilePickerConfig {
    public var useCamera = false;
    public var useLibrary = true;
    public var useCloud = true;
}


public class WMFilePicker: NSObject,
    UINavigationControllerDelegate,
    UIImagePickerControllerDelegate,
    UIDocumentPickerDelegate {
    
    public static let sharedInstance = WMFilePicker();
    
    public let config = WMFilePickerConfig()
    
    private var presentingViewController: UIViewController?;
    
    private var completionHandler: (([URL]) -> Void)?
    
    private override init() {
        
    }
    
    public func present(vc: UIViewController, type: String, multiple: Bool = false, onCompletion: @escaping (_ urls: [URL]) -> Void) {

        self.completionHandler = onCompletion;
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet);
        var handler = {(a:UIAlertAction?) in };
        if (type == IMAGE || type == VIDEO) {
            if (self.config.useCamera
                && UIImagePickerController.isSourceTypeAvailable(.camera)) {
                let title = type == IMAGE ? "Take Picture" : "Capture Video";
                handler = {(a) in
                    self.capture(vc: vc, type: type);
                };
                alert.addAction(UIAlertAction(title: title, style: .default, handler: handler));
            }
            if (self.config.useLibrary) {
                handler = {(a) in
                    self.showLibraryUI(view: vc, type: type, multiple: multiple);
                };
                alert.addAction(UIAlertAction(title: "Pick From Library", style: .default, handler: handler));
            }
        }
        if (self.config.useCloud) {
            handler = {(a) in
                self.showCloudUI(vc: vc, type: type, multiple: multiple);
            };
            alert.addAction(UIAlertAction(title: "Pick From Cloud", style: .default, handler: handler));
        }
        if (alert.actions.count == 1) {
            handler(nil);
        } else {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil));
                vc.present(alert, animated: true, completion: nil);
        }
    }
    
    private func capture(vc: UIViewController, type: String) {
        let cameraPicker = UIImagePickerController()
        cameraPicker.sourceType = .camera;
        cameraPicker.showsCameraControls = true;
        cameraPicker.delegate = self;
        if(type == VIDEO) {
            cameraPicker.mediaTypes = [String(kUTTypeMovie)];
        } else {
            cameraPicker.mediaTypes = [String(kUTTypeImage)]
        }
        vc.present(cameraPicker, animated: true, completion: nil);
        self.presentingViewController = cameraPicker;
    }
    
    private func showCloudUI(vc: UIViewController, type: String, multiple: Bool) {
        var types = [String(kUTTypeData)];
        if(type == IMAGE) {
            types = [String(kUTTypeImage)]
        } else if(type == VIDEO) {
            types = [String(kUTTypeVideo)]
        } else if(type == AUDIO) {
            types = [String(kUTTypeAudio)]
        }
        let picker = UIDocumentPickerViewController(documentTypes: types, in: .import);
        if #available(iOS 11.0, *) {
            picker.allowsMultipleSelection = multiple
        }
        picker.delegate = self;
        vc.present(picker, animated: true, completion: nil);
    }
    
    private func showLibraryUI(view: UIViewController, type: String, multiple: Bool) {
        let picker = UIImagePickerController();
        picker.delegate = self;
        picker.sourceType = .photoLibrary;
        if (type == IMAGE) {
            picker.mediaTypes = ["public.image"];
        } else if (type == VIDEO) {
            picker.mediaTypes = ["public.movie"];
        } else if (type == AUDIO) {
            picker.mediaTypes = ["public.audio"];
        }
        view.present(picker, animated: true, completion: nil);
        self.presentingViewController = picker;
    }
    
    //MARK: UIImagePickerControllerDelegate
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let mediaType = info[UIImagePickerController.InfoKey.mediaType] as! NSString
        if mediaType ==  "public.movie" {
            let videoURL = info[UIImagePickerController.InfoKey.mediaURL] as! URL;
            let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask);
            let destUrl = URL(string: cachePath[0].absoluteString + videoURL.lastPathComponent);
            do {
                try FileManager.default.copyItem(at: videoURL, to: destUrl!);
            } catch let error {
                print("Error: \(error)");
            }
            self.completionHandler?([destUrl!])
        } else {
            let originalImage: UIImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
            var imageUrl: URL? = nil
            if let data = originalImage.pngData() {
                let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask);
                imageUrl = URL(string: paths[0].absoluteString + UUID.init().uuidString + ".png")
                try? data.write(to: imageUrl!)
            }
            self.completionHandler?([imageUrl!]);
        }
        self.presentingViewController?.dismiss(animated: true, completion: nil);
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.completionHandler?([URL]());
        self.presentingViewController?.dismiss(animated: true, completion: nil);
    }
    
    // MARK: UIDocumentPickerDelegate
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        self.completionHandler?([url]);
    }
    
    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
      self.completionHandler?([URL]())
    }
    
    private func getURLs(_ assets: [PHAsset], i: Int = 0, urls: [URL] = []) {
        var _urls = [URL](urls);
        if( i >= assets.count) {
            self.completionHandler?(urls);
            return;
        }
        self.getURL(asset: assets[i], completionHandler: { (url: URL?) in
            _urls.append(url!);
            self.getURLs(assets, i: i + 1, urls: _urls);
        });
    }
    
    private func getURL(asset: PHAsset, completionHandler : @escaping ((_ responseURL : URL?) -> Void)){
        if asset.mediaType == .image {
            let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData) -> Bool in
                return true
            }
            asset.requestContentEditingInput(with: options, completionHandler: {(contentEditingInput: PHContentEditingInput?, info: [AnyHashable : Any]) -> Void in
                completionHandler(contentEditingInput!.fullSizeImageURL as URL?)
            })
        } else if asset.mediaType == .video {
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.version = .original
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options, resultHandler: {(asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable : Any]?) -> Void in
                if let urlAsset = asset as? AVURLAsset {
                    let localVideoUrl: URL = urlAsset.url as URL
                    completionHandler(localVideoUrl)
                } else {
                    completionHandler(nil)
                }
            })
        } else if asset.mediaType == .audio {
            let options: PHVideoRequestOptions = PHVideoRequestOptions();
            options.version = .original;
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options, resultHandler: {(asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable : Any]?) -> Void in
                if let urlAsset = asset as? AVURLAsset {
                    let localVideoUrl: URL = urlAsset.url as URL
                    completionHandler(localVideoUrl)
                } else {
                    completionHandler(nil)
                }
            })
        }
    }
}

@objc(WMFilePickerPlugin)
public class WMFilePickerPlugin: CDVPlugin {
    
    @objc
    public func selectFiles(_ command: CDVInvokedUrlCommand) {
        let options = command.argument(at: 0) as! [String: NSObject];
        let type = options["type"] as? String ?? "IMAGE";
        let multiple = options["multiple"] as? Bool ?? false;
        WMFilePicker.sharedInstance.config.useCamera = options["useCamera"] as? Bool ?? false;
        WMFilePicker.sharedInstance.config.useLibrary = options["useLibrary"] as? Bool ?? true;
        WMFilePicker.sharedInstance.config.useCloud = options["useICloud"] as? Bool ?? true;
        WMFilePicker.sharedInstance.present(vc: viewController, type: type, multiple: multiple, onCompletion:{ (urls: [URL]) in
            let paths = urls.map { url in url.absoluteString };
            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: paths);
            self.commandDelegate.send(result, callbackId: command.callbackId);
        });
    }
}