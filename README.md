Game Development with AI
========================

Project: **COIN CIRCUIT CHASE**
-------------------------------

### Team Members

*   **Garima Dhakal**
    
*   **Sajid Ali Sadruddin**
    
*   **Shavik Balyan**
    
*   **Shivam Gupta**
    

**TU Dresden**

Project Overview
----------------

**COIN CIRCUIT CHASE** is a multi-level robot minigame environment designed to explore reinforcement learning in game development. The robot must navigate through various levels, collect coins, avoid enemies, and reach the portal to progress. The project leverages advanced AI techniques, including Proximal Policy Optimization (PPO) and Soft Actor-Critic (SAC), to train agents for optimal performance.

Installation & Dependencies
---------------------------

### Godot Engine

*   Download **Godot** with .NET (C#) support from:[https://godotengine.org/](https://godotengine.org/)
    

### Python Packages

*   pip install stable-baselines3\[extra\]
    

Environment Description
-----------------------

### Multilevel Robot Environment

*   **Objective:** Guide the robot through multiple mini-levels, collecting all coins and avoiding enemies to reach the portal.
    
*   **Levels:** Each level may contain coins and/or enemy robots. All coins must be collected before proceeding.
    
*   **Final Level:** Features enemy robots that must be avoided.
    

### Observations

The agent receives the following observations:

*   Current n\_steps / reset\_after
    
*   Position of the current level's goal (in robot's local reference)
    
*   Position of the closest coin (in robot's local reference)
    
*   Position of the closest enemy (in robot's local reference)
    
*   Movement direction of the closest enemy
    
*   Robot velocity
    
*   Whether all coins for the current level have been collected (0 or 1)
    

### Game Over / Episode End Conditions

An episode ends if:

*   The robot falls
    
*   The robot collides with an enemy robot
    
*   The robot finishes a level by passing through the portal
    

Training the Agent
------------------

### PPO Training

To train using Proximal Policy Optimization (PPO), use the stable\_baselines3\_example.py file:

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   python3 stable_baselines3_example.py --save_model_path ppo-final --linear_lr_schedule True --speedup 5 --experiment_name ppo-final --onnx_export_path ppo-final-onnx --save_checkpoint_frequency 50000   `

### SAC Training

To train using Soft Actor-Critic (SAC), use the sac\_stableBaselines3.py file.

Running Inference with Pretrained ONNX Model
--------------------------------------------

1.  Open the project in Godot.
    
2.  Open the training\_scene.
    
3.  Click on **Run Current Scene** or press F6.
    

Training in Godot
-----------------

*   The default scene (training\_scene) is set up for training.
    
*   You can use either PPO or SAC as described above.
    

Contact
-------

For any questions or contributions, please contact any of the team members listed above.

**COIN CIRCUIT CHASE**_Game Development with AI – TU Dresden_