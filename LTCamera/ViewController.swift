//
//  ViewController.swift
//
//  Created by Zhengfei,Yu on 2018/10/20.
//  Copyright © 2018年 mFlywork. All rights reserved.
//

import UIKit
import GPUImage
import AVKit


let kWidth: CGFloat = UIScreen.main.bounds.size.width
let kHeight: CGFloat = UIScreen.main.bounds.size.height
public func RGBA (r:CGFloat, g:CGFloat, b:CGFloat, a:CGFloat) -> UIColor {
    return UIColor (red: r/255.0, green: g/255.0, blue: b/255.0, alpha: a)
}

class ViewController: UIViewController {

    // 摄像头
    fileprivate var camera: GPUImageVideoCamera?
    
    // 写入对象
    fileprivate var movieWriter : GPUImageMovieWriter?
    
//    fileprivate lazy var stillCamera: GPUImageStillCamera? = GPUImageStillCamera(sessionPreset: AVCaptureSessionPresetHigh, cameraPosition: .front)
    
    fileprivate lazy var preView: GPUImageView  = {
        let preView = GPUImageView(frame: self.view.bounds)
        return preView
    }()
    
    let saturationFilter = GPUImageSaturationFilter() // 饱和
    let bilateralFilter = GPUImageBilateralFilter() // 磨皮
    let brightnessFilter = GPUImageBrightnessFilter() // 美白
    let exposureFilter = GPUImageExposureFilter() // 曝光
    
    fileprivate var player: AVPlayer?   //播放器
    fileprivate var isEndRecording = false
    
    // 视频存放路径Url
    var fileURL : URL {
        return URL(fileURLWithPath: pathString)
    }
    
    // 视频存放路径
    var pathString: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/test.mp4"
    }
    
    fileprivate lazy var filterView: LTFilterView  = {
        let filterView = LTFilterView(frame: self.view.bounds)
        return filterView
    }()
    
    // 播放器Layer
    fileprivate lazy var playerLayer: AVPlayerLayer = {
        let layer = AVPlayerLayer()
        layer.frame = CGRect(x: (kWidth - 220)/2.0, y: 210, width: 220, height: 220)
//        layer.backgroundColor = UIColor.red.cgColor
        return layer
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layoutViews()
        configSliderChange()
        configSwitchChange()
    }
    
    override var prefersStatusBarHidden: Bool{
        return true
    }
}

extension ViewController {
    
    // 初始化摄像头
    fileprivate func configCamera() {
        if camera == nil {
            camera = GPUImageVideoCamera(sessionPreset: AVCaptureSessionPresetHigh, cameraPosition: .front)
        }
        
        if movieWriter == nil {
            if FileManager.default.fileExists(atPath: self.pathString) {
                try? FileManager.default.removeItem(atPath: self.pathString)
            }
            movieWriter = GPUImageMovieWriter(movieURL: self.fileURL, size: (self.view.bounds.size))
            movieWriter?.encodingLiveVideo = true
        }
        
        //设置camera方向
        camera?.outputImageOrientation = .portrait
        camera?.horizontallyMirrorFrontFacingCamera = true
        
        //camera 翻转
        camera?.rotateCamera()
        
        ///防止允许声音通过的情况下，避免录制第一帧黑屏闪屏
        camera?.addAudioInputsAndOutputs()
        
        //获取滤镜组
        let filterGroup = getGroupFilters()
        //设置默认值
        bilateralFilter.distanceNormalizationFactor = 5.5
        exposureFilter.exposure = 0
        brightnessFilter.brightness = 0
        saturationFilter.saturation = 1.0
        //设置GPUImage的响应链
        camera?.addTarget(filterGroup)
        filterGroup.addTarget(movieWriter)
        filterGroup.addTarget(preView)
    }
    
    // 初始化writer
    fileprivate func configWriter() {
        if movieWriter == nil {
            if FileManager.default.fileExists(atPath: self.pathString) {
                try? FileManager.default.removeItem(atPath: self.pathString)
            }
            movieWriter = GPUImageMovieWriter(movieURL: self.fileURL, size: (self.view.bounds.size))
            movieWriter?.encodingLiveVideo = true
        }
//        let filterGroup = getGroupFilters()
//        // 将writer设置成滤镜的target
//        filterGroup.addTarget(movieWriter)
    }
    
    fileprivate func getGroupFilters() -> GPUImageFilterGroup {
        //创建滤镜组
        let filterGroup = GPUImageFilterGroup()
        //创建滤镜(设置滤镜的引来关系)
        bilateralFilter.addTarget(brightnessFilter)
        brightnessFilter.addTarget(exposureFilter)
        exposureFilter.addTarget(saturationFilter)
        //设置滤镜起点 终点的filter
        filterGroup.initialFilters = [bilateralFilter]
        filterGroup.terminalFilter = saturationFilter
        return filterGroup
    }
    
}

extension ViewController : GPUImageVideoCameraDelegate {
    //
    func willOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer!) {
//        print("采集到的数据\(sampleBuffer)")
    }
}


extension ViewController {

    //翻转
    @objc fileprivate func pickUpCameraSelected() {
        camera?.rotateCamera()
    }
    
    //滤镜
    @objc fileprivate func filterCameraSelected() {
        filterView.show()
    }
    
    // 开始录制
    @objc fileprivate func starRecordSelected() {
        // 先移除页面上的播放器
        playerLayer.removeFromSuperlayer()
        
        //创建预览的View
        view.insertSubview(preView, at: 0)
        
        //配置摄像头
        configCamera()
        //配置writer
//        configWriter()
        
        //开始采集视频
        camera?.startCapture()
        camera?.delegate = self
        camera?.audioEncodingTarget = movieWriter
        movieWriter?.startRecording()
    }
    
    //结束录制
    @objc fileprivate func endRecordSelected() {
        isEndRecording = true
        preView.removeFromSuperview()
        movieWriter?.finishRecording()
        movieWriter = nil
        let filterGroup = getGroupFilters()
        filterGroup.removeTarget(movieWriter)
        camera?.stopCapture()
        camera?.audioEncodingTarget = nil
        camera = nil
    }
    
    //播放
    @objc fileprivate func playRecordSelected() {
        print(fileURL)
        if !FileManager.default.fileExists(atPath: pathString) {
            showAlert("播放路径不存在")
            return
        }
        let playerItem = AVPlayerItem(url: fileURL)
        player = AVPlayer(playerItem: playerItem)
        playerLayer.player = player
        view.layer.addSublayer(playerLayer)
        player?.play()
    }

    //清除缓存
    @objc fileprivate func clearCacheSelected() {
        // 移除播放器
        playerLayer.removeFromSuperlayer()
        
        if isEndRecording == false {
            showAlert("正在录制视频, 录制完成后进行清除")
            return
        }
        
        if FileManager.default.fileExists(atPath: pathString) {
            do {
                try FileManager.default.removeItem(atPath: pathString)
                showAlert("清除成功")
            } catch {
                showAlert("清除失败")
            }
        }else{
            showAlert("缓存已清除")
        }
    }
    
    //拍照
    @objc fileprivate func takePhotoSelected() {
        
        guard let camera = camera else {
            fatalError("请退出程序重新录制！")
        }
        
        if camera.isMember(of: GPUImageVideoCamera.self)  {
            showAlert("请查看takePhotoSelected方法的说明")
            return
        }
        
        /*说明：
        GPUImageVideoCamera：通常用于实时视频的录制
        GPUImageStillCamera：用于拍摄当前手机的画面, 并且保存图片
        1. 将fileprivate lazy var camera: GPUImageVideoCamera? = GPUImageVideoCamera(sessionPreset: AVCaptureSessionPresetHigh, cameraPosition: .front)
        改为
        fileprivate lazy var camera: GPUImageStillCamera? = GPUImageStillCamera(sessionPreset: AVCaptureSessionPresetHigh, cameraPosition: .front)
        2. 取消以下注释
        */
        
//        camera.capturePhotoAsImageProcessedUp(toFilter: getGroupFilters(), withCompletionHandler: {[weak self] (image, error) in
//            if error == nil {
//                UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
//                self?.showAlert("图片保存成功，请退出程序重新录制！")
//            }else{
//                self?.showAlert("图片保存失败，请退出程序重新录制！")
//            }
//            self?.endRecordSelected()
//        })
 
    }
}

//MARK: 根据滑动改变美颜效果
extension ViewController {
    
    //根据滑动改变美颜效果
    fileprivate func configSliderChange() {
        
        filterView.sliderDidValueChanged = {[weak self] (_, slider, type) in
            print(slider.value)
            switch type {
                
            case .bilateralFilter:
                self?.bilateralFilter.distanceNormalizationFactor = 10.0 - CGFloat(slider.value)
                break
                
            case .exposureFilter:
                self?.exposureFilter.exposure = CGFloat(slider.value) * 20.0 - 10.0
                break
                
            case .brightnessFilter:
                self?.brightnessFilter.brightness = CGFloat(slider.value) * 2.0 - 1.0
                break
                
            case .saturationFilter:
                self?.saturationFilter.saturation = CGFloat(slider.value) * 2.0
                break
        
            }
        }
        
    }
    
    //开关美颜功能
    fileprivate func configSwitchChange() {
        
        filterView.switchDidValueChanged = {[weak self] (_, filterSwitch, isOpen) in
            if isOpen {
                self?.camera?.removeAllTargets()
                let group = self?.getGroupFilters()
                self?.camera?.addTarget(group)
                group?.addTarget(self?.preView)
            }else{
                self?.camera?.removeAllTargets()
                self?.camera?.addTarget(self?.preView)
            }
        }
        
    }
}


//MARK:  ---  布局  ---
extension ViewController {
    
    fileprivate func layoutViews() {
        
        // 翻转按钮
        let pickUpCamera = circleButton(frame: CGRect(x: kWidth - 70, y: 64, width: 55, height: 55), title: "翻转", action: #selector(pickUpCameraSelected), view: view)
        
        // 滤镜
        circleButton(frame: CGRect(x: pickUpCamera.frame.origin.x - 15 - 55, y: 64, width: 55, height: 55), title: "滤镜", action: #selector(filterCameraSelected), view: view)
        
        // 拍照
        circleButton(frame: CGRect(x: kWidth - 70, y: 134, width: 55, height: 55), title: "拍照", action: #selector(takePhotoSelected), view: view)
        
        // 开始录制
        rectangleButton(frame: CGRect(x: 15, y: 65, width: 70, height: 30), title: "开始录制", action: #selector(starRecordSelected), view: view)
        
        // 结束录制
        rectangleButton(frame: CGRect(x: 15, y: 110, width: 70, height: 30), title: "结束录制", action: #selector(endRecordSelected), view: view)
        
        // 播放
        rectangleButton(frame: CGRect(x: 15, y: 155, width: 70, height: 30), title: "播放", action: #selector(playRecordSelected), view: view)
        
        // 清除缓存
        rectangleButton(frame: CGRect(x: 15, y: 200, width: 70, height: 30), title: "清除缓存", action: #selector(clearCacheSelected), view: view)

        view.addSubview(filterView)
        
    }
 
}

typealias sliderValueChangedClosure = (LTFilterView, UISlider, sliderFilterType) -> Void
typealias switchValueChangedClosure = (LTFilterView, UISwitch, Bool) -> Void


enum sliderFilterType: Int {
    case bilateralFilter = 0
    case exposureFilter
    case brightnessFilter
    case saturationFilter
}

class LTFilterView: UIView {
    
    fileprivate let bgHeight: CGFloat = 250.0
    fileprivate lazy var sliders: [UISlider] = [UISlider]()
    var sliderDidValueChanged: sliderValueChangedClosure?
    var filterType: sliderFilterType = .bilateralFilter
    var switchDidValueChanged: switchValueChangedClosure?
    
    
    fileprivate lazy var bgView: UIView = {
        let bgView = UIView(frame: CGRect(x: 0, y: kHeight, width: kWidth, height: self.bgHeight))
        bgView.backgroundColor = RGBA(r: 0, g: 0, b: 0, a: 0.35)
        return bgView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configFilterView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

//MARK:  点击空白处隐藏
extension LTFilterView {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let currentView = touches.first?.location(in: bgView) else {
            return ;
        }
        if !self.point(inside: currentView, with: event)  {
            dismiss()
        }
    }
    
}

extension LTFilterView {
    
    fileprivate func configFilterView() {
        self.isHidden = true
        addSubview(bgView)
        configBgViewSubViews()
        configSlider()
        configSwitch()
    }
    
    private func configBgViewSubViews() {
        let titles = ["磨皮", "曝光", "美白", "饱和"]
        var labelY: CGFloat = 0.0
        let labelH: CGFloat = 40
        for index in 0..<titles.count {
            labelY = bgHeight - labelH * CGFloat(index + 1) - 10
            let label = leftLabel(frame: CGRect(x: 0, y: labelY, width: 80, height: 40), text: titles[titles.count - index - 1], view: bgView)
            
            let slider = sliderBase(frame: CGRect(x: label.frame.origin.x + label.frame.width, y: labelY, width: kWidth - label.frame.width - 10, height: 40), action: #selector(sliderValueChanged(_:)), view: bgView)
            slider.tag = titles.count - index - 1
            sliders.insert(slider, at: 0)
        }
    }
    
    private func configSlider() {
        for (index, slider) in sliders.enumerated(){
            if let type = sliderFilterType(rawValue: index){
                switch type{
                    case .bilateralFilter:
                        slider.minimumValue = 1.0
                        slider.maximumValue = 10.0
                        slider.value = 5.5
                        break
                        
                    case .brightnessFilter, .exposureFilter, .saturationFilter:
                        slider.value = 0.5
                        break
                }
            }else{
                print("error enum")
                continue
            }
        }
    }
    
    @objc private func sliderValueChanged(_ slider: UISlider) {
        guard let sliderDidValueChanged = sliderDidValueChanged else {
            return
        }
        sliderDidValueChanged(self, slider, sliderFilterType(rawValue: slider.tag) ?? .bilateralFilter)
    }
    
    private func configSwitch() {
        let filterSwitch = UISwitch()
        filterSwitch.center = CGPoint(x: kWidth/2.0, y: 32)
        filterSwitch.setOn(true, animated: true)
        filterSwitch.onTintColor = RGBA(r: 231, g: 85, b: 87, a: 0.8)
        filterSwitch.tintColor = RGBA(r: 231, g: 85, b: 87, a: 0.8)
        filterSwitch.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
        bgView.addSubview(filterSwitch)
    }
    
    @objc private func switchValueChanged(_ filterSwitch: UISwitch) {
        guard let switchDidValueChanged = switchDidValueChanged else {
            return
        }
        switchDidValueChanged(self, filterSwitch, filterSwitch.isOn)
    }

}

extension LTFilterView {
    
    func show() {
        self.isHidden = false
        UIView.animate(withDuration: 0.25, animations: {
            self.bgView.frame.origin.y = kHeight - self.bgHeight
        })
    }
    
    func dismiss() {
        UIView.animate(withDuration: 0.25, animations: {
            self.bgView.frame.origin.y = kHeight
        }) { (completed) in
            self.isHidden = true
        }
    }
}



//MARK:  -- Base --
extension UIResponder {
    
    @discardableResult
    fileprivate func circleButton(frame: CGRect, title: String?, action: Selector, view: UIView) -> UIButton {
        let button = baseButton(frame: frame, view: view)
        button.layer.cornerRadius = button.frame.height / 2.0
        button.clipsToBounds = true
        button.layer.masksToBounds = true
        button.setTitleColor(UIColor.white, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.backgroundColor = RGBA(r: 231, g: 85, b: 87, a: 0.8)
        return button
    }
    
    @discardableResult
    fileprivate func rectangleButton(frame: CGRect, title: String?, action: Selector, view: UIView) -> UIButton {
        let button = baseButton(frame: frame, view: view)
        button.layer.cornerRadius = 3.0
        button.clipsToBounds = true
        button.layer.masksToBounds = true
        button.setTitleColor(UIColor.white, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.backgroundColor = RGBA(r: 39, g: 161, b: 98, a: 0.8)
        return button
    }
    
    private func baseButton(frame: CGRect, view: UIView) -> UIButton {
        let button = UIButton(type: .custom)
        button.frame = frame
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        view.addSubview(button)
        return button
    }
    
    fileprivate func leftLabel(frame: CGRect, text: String?, view: UIView) -> UILabel {
        let label = UILabel(frame: frame)
        label.textAlignment = .center
        label.text = text
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 15)
        view.addSubview(label)
        return label
    }
    
    fileprivate func sliderBase(frame: CGRect, action: Selector, view: UIView) -> UISlider {
        let slider = UISlider(frame: frame)
        slider.tintColor = RGBA(r: 231, g: 85, b: 87, a: 0.8)
        slider.addTarget(self, action: action, for: .valueChanged)
        view.addSubview(slider)
        return slider
    }
    
    fileprivate func showAlert(_ title: String?) {
        UIAlertView(title: nil, message: title, delegate: nil, cancelButtonTitle: "取消").show()
    }
}

