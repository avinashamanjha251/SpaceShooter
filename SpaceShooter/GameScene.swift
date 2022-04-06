//
//  GameScene.swift
//  SpaceShooter
//
//  Created by Avinash on 05/04/22.
//

import SpriteKit
import GameplayKit
import CoreMotion
import AVFoundation

class GameScene: SKScene {
    
    enum EndReason {
        case kEndReasonWin, kEndReasonLose
    }
        
    private var _parallaxNodeBackgrounds: FMMParallaxNode?
    private var _parallaxSpaceDust: FMMParallaxNode?
    private lazy var _motionManager: CMMotionManager = CMMotionManager()
    
    private var kNumAsteroids = 15
    private var _asteroids = [SKSpriteNode]()
    private var _nextAsteroid = 0
    private var _nextAsteroidSpawn = 0.0
    
    private var kNumLasers = 15
    private var _shipLasers = [SKSpriteNode]()
    private var _nextShipLaser = 0
    
    private var _lives = 0
    private var _gameOverTime = 0.0
    private var _gameOver = false

    private var _backgroundAudioPlayer: AVAudioPlayer?
    
    private lazy var shipNode : SKSpriteNode = {
        let shipNode = SKSpriteNode(imageNamed: "SpaceFlier_sm_1")
        return shipNode
    }()
    
    override init(size: CGSize) {
        super.init(size: size)
        self.backgroundColor = .black
        gameBackground(size: size)

        shipNode.position = CGPoint(x: self.frame.size.width*0.1, y: self.frame.midY)
        addPhysicsOnShipNode()
        addChild(shipNode)
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        startSetup()
        setupAsteroids()
        setupShipLaser()
        startBackgroundMusic()
        startTheGame()
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init(coder: aDecoder)
        fatalError("init(coder:) has not been implemented")
    }
    
    override func update(_ currentTime: TimeInterval) {
        let curTime = CACurrentMediaTime()

        _parallaxSpaceDust?.update(currentTime)
        _parallaxNodeBackgrounds?.update(currentTime)
        updateShipPositionFromMotionManager()
        updateAsteroidsMotion(curTime: curTime)
        addCollisionDetection()
        endGame(curTime: curTime)
    }
    
    func gameBackground(size: CGSize) {
        let parallaxBackgroundNames = ["bg_galaxy", "bg_planetsunrise", "bg_spacialanomaly", "bg_spacialanomaly2"]
        let parallaxBackground2Names = ["bg_front_spacedust", "bg_front_spacedust"]
        let planetSizes = CGSize(width: 200, height: 200)
        if let _parallaxNodeBackgrounds = FMMParallaxNode(backgrounds: parallaxBackgroundNames, size: planetSizes, pointsPerSecondSpeed: 10.0) {
            _parallaxNodeBackgrounds.position = CGPoint(x: size.width/2.0, y: size.height/2.0)
            _parallaxNodeBackgrounds.randomizeNodesPositions()
            self._parallaxNodeBackgrounds = _parallaxNodeBackgrounds
            addChild(_parallaxNodeBackgrounds)
        }
        if let _parallaxSpaceDust = FMMParallaxNode(backgrounds: parallaxBackground2Names, size: size, pointsPerSecondSpeed: 25) {
            _parallaxSpaceDust.position = CGPoint(x: 0, y: 0)
            self._parallaxSpaceDust = _parallaxSpaceDust
            addChild(_parallaxSpaceDust)
        }
    }
    
    func startSetup() {
        do {
            try addChild(loadEmitterNode(emitterFileName: "stars1"))
            try addChild(loadEmitterNode(emitterFileName: "stars2"))
            try addChild(loadEmitterNode(emitterFileName: "stars3"))
        }
        catch {
            print(error)
        }
    }
    func loadEmitterNode(emitterFileName: String) throws -> SKEmitterNode {
        let emitterPath = Bundle.main.url(forResource: emitterFileName, withExtension: "sks")!
        let fileData = try Data(contentsOf: emitterPath)
        let emitterNode = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(fileData) as! SKEmitterNode
        //do some view specific tweaks
        emitterNode.particlePosition = CGPoint(x: self.size.width/2.0, y: self.size.height/2.0)
        emitterNode.particlePositionRange = CGVector(dx: self.size.width+100, dy: self.size.height)
        return emitterNode
    }
    
    func startTheGame() {
        _lives = 3
        let curTime = CACurrentMediaTime()
        _gameOverTime = curTime + 30.0
        _gameOver = false

        _nextAsteroidSpawn = 0
        for asteroid in _asteroids {
            asteroid.isHidden = true
        }
        for laser in _shipLasers {
            laser.isHidden = true
        }
        shipNode.isHidden = false
        //reset ship position for new game
        shipNode.position = CGPoint(x: self.frame.size.width * 0.1, y: self.frame.midY)
        
        //setup to handle accelerometer readings using CoreMotion Framework
        startMonitoringAcceleration()
        
    }
    
    func startMonitoringAcceleration() {
        if (_motionManager.isAccelerometerAvailable) {
            _motionManager.startAccelerometerUpdates()
            print("accelerometer updates on...")
        }
    }
    
    func stopMonitoringAcceleration() {
        if (_motionManager.isAccelerometerAvailable && _motionManager.isAccelerometerActive) {
            _motionManager.stopAccelerometerUpdates()
            print("accelerometer updates off...")
        }
    }
    
    func updateShipPositionFromMotionManager() {
        guard let data = _motionManager.accelerometerData else { return }
        if (fabs(data.acceleration.x) > 0.2) {
            print("acceleration value = \(data.acceleration.x)")
            shipNode.physicsBody?.applyForce(CGVector(dx: 0.0, dy: 40.0 * data.acceleration.x))
            
        }
    }
    
    func addPhysicsOnShipNode() {
        //move the ship using Sprite Kit's Physics Engine
        //1
        shipNode.physicsBody = SKPhysicsBody(rectangleOf: shipNode.frame.size)
        
        //2
        shipNode.physicsBody?.isDynamic = true
        
        //3
        shipNode.physicsBody?.affectedByGravity = false
        
        //4
        shipNode.physicsBody?.mass = 0.02
        
    }
    
    func setupAsteroids() {
        for _ in 0...kNumAsteroids {
            let asteroid = SKSpriteNode(imageNamed: "asteroid")
            asteroid.isHidden = true
            asteroid.xScale = 0.5
            asteroid.yScale = 0.5
            _asteroids.append(asteroid)
            addChild(asteroid)
        }
    }
    func setupShipLaser() {
        for _ in 0...kNumLasers {
            let shipLaser = SKSpriteNode(imageNamed: "laserbeam_blue")
            shipLaser.isHidden = true
            _shipLasers.append(shipLaser)
            addChild(shipLaser)
        }
    }
    
    func randomValueBetween(low: Float, andValue high: Float) -> Float {
        return Float.random(in: low..<high)
    }
    
    func updateAsteroidsMotion(curTime: CFTimeInterval) {
        if (curTime > _nextAsteroidSpawn) {
            let randSecs = randomValueBetween(low: 0.20, andValue: 1.0)
            _nextAsteroidSpawn = Double(randSecs) + curTime;
            let randY = randomValueBetween(low: 0.0, andValue: Float(self.frame.size.height))
            let randDuration = randomValueBetween(low: 2.0, andValue: 10.0)
            let asteroid = _asteroids[_nextAsteroid]
            _nextAsteroid += 1
            if (_nextAsteroid >= _asteroids.count) {
                _nextAsteroid = 0
            }
            asteroid.removeAllActions()
            asteroid.position = CGPoint(x: self.frame.size.width+asteroid.size.width/2, y: CGFloat(randY))
            asteroid.isHidden = false
            let location = CGPoint(x: -self.frame.size.width-asteroid.size.width, y: CGFloat(randY))
            let moveAction = SKAction.move(to: location, duration: TimeInterval(randDuration))
            let doneAction = SKAction.run {
                asteroid.isHidden = true
            }
            let moveAsteroidActionWithDone = SKAction.sequence([moveAction, doneAction])
            asteroid.run(moveAsteroidActionWithDone, withKey: "asteroidMoving")
        }
    }
    
    func addCollisionDetection() {
        //check for laser collision with asteroid
        for asteroid in _asteroids {
            if (asteroid.isHidden) {
                continue;
            }
            for shipLaser in _shipLasers {
                if (shipLaser.isHidden) {
                    continue;
                }
                if shipLaser.intersects(asteroid) {
                    let asteroidExplosionSound = SKAction.playSoundFileNamed("explosion_small.caf", waitForCompletion: false)
                    asteroid.run(asteroidExplosionSound)
                    shipLaser.isHidden = true
                    asteroid.isHidden = true
                    
                    print("you just destroyed an asteroid");
                    continue;
                }
            }
            if shipNode.intersects(asteroid) {
                asteroid.isHidden = true
                let blink = SKAction.sequence([SKAction.fadeOut(withDuration: 0.1), SKAction.fadeIn(withDuration: 0.1)])
                let shipExplosionSound = SKAction.playSoundFileNamed("explosion_large.caf", waitForCompletion: false)
                let blinkForTime = SKAction.repeat(blink, count: 4)
                shipNode.run(SKAction.sequence([shipExplosionSound, blinkForTime]))
                _lives -= 1
                print("your ship has been hit!");
            }
        }
    }
    
    func endGame(curTime: CFTimeInterval) {
        // Add at end of update loop
        if (_lives <= 0) {
            print("you lose...");
            endTheScene(endReason: .kEndReasonLose)
        } else if (curTime >= _gameOverTime) {
            print("you won...");
            endTheScene(endReason: .kEndReasonWin)
        }
    }
    
    func endTheScene(endReason: EndReason) {
        if (_gameOver) {
            return;
        }
        removeAllActions()
        
        stopMonitoringAcceleration()
        shipNode.isHidden = true
        _gameOver = true
        
        var message = ""
        if (endReason == .kEndReasonWin) {
            message = "You win!"
        } else if (endReason == .kEndReasonLose) {
            message = "You lost!"
        }
        
        let label = SKLabelNode(fontNamed: "Futura-CondensedMedium")
        label.name = "winLoseLabel"
        label.text = message
//        label.scale = 0.1
        label.position = CGPoint(x: self.frame.size.width/2, y: self.frame.size.height * 0.6);
        label.fontColor = .yellow
        addChild(label)
        
        
        let restartLabel = SKLabelNode(fontNamed: "Futura-CondensedMedium")
        restartLabel.name = "restartLabel"
        restartLabel.text = "Play Again?"
//        restartLabel.scale = 0.5
        restartLabel.position = CGPoint(x: self.frame.size.width/2, y: self.frame.size.height * 0.4);
        restartLabel.fontColor = .yellow
        addChild(restartLabel)
        
        let labelScaleAction = SKAction.scale(to: 1.0, duration: 0.5)
        restartLabel.run(labelScaleAction)
        label.run(labelScaleAction)
    }

    func startBackgroundMusic() {
        guard let filePath = Bundle.main.path(forResource: "SpaceGame.caf", ofType: nil) else { return }
       let filePathUrl = URL(fileURLWithPath: filePath)
       
        do {
            _backgroundAudioPlayer = try AVAudioPlayer(contentsOf: filePathUrl)
            _backgroundAudioPlayer?.prepareToPlay()
            _backgroundAudioPlayer?.numberOfLoops = -1
            _backgroundAudioPlayer?.volume = 1
            _backgroundAudioPlayer?.play()
        }
        catch {
            print("error in audio play \(error)")
        }
    }

}

extension GameScene {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //check if they touched your Restart Label
        for touch in touches {
            
            if let n = nodes(at: touch.location(in: self)).first {
                if (n != self && n.name == "restartLabel") {
                    childNode(withName: "restartLabel")?.removeFromParent()
                    childNode(withName: "winLoseLabel")?.removeFromParent()
                    startTheGame()
                    return;
                }
            }
        }

        //do not process anymore touches since it's game over
        if (_gameOver) {
            return
        }

        /* Called when a touch begins */
        //1
        let shipLaser = _shipLasers[_nextShipLaser]
        _nextShipLaser += 1
        if (_nextShipLaser >= _shipLasers.count) {
            _nextShipLaser = 0
        }
        
        //2
        shipLaser.position = CGPoint(x: shipNode.position.x+shipLaser.size.width/2,y: shipNode.position.y+0);
        shipLaser.isHidden = false
        shipLaser.removeAllActions()
        
        //3
        let location = CGPoint(x: self.frame.size.width, y: shipNode.position.y);
        let laserFireSoundAction = SKAction.playSoundFileNamed("laser_ship.caf", waitForCompletion: false)
        let laserMoveAction = SKAction.move(to: location, duration: 0.5)
        //4
        let laserDoneAction = SKAction.run {
            shipLaser.isHidden = true
        }
        //5
        let moveLaserActionWithDone = SKAction.sequence([laserFireSoundAction,laserMoveAction,laserDoneAction])
        //6
        shipLaser.run(moveLaserActionWithDone, withKey: "laserFired")
        
    }
    
}
