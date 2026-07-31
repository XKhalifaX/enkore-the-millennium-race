using Godot;

public partial class vehicle_Interactable : Node3D
{
	[Export] public NodePath VehicleControllerPath = "VehicleController";
	[Export] public NodePath ExitPointPath = "ExitPoint";
	[Export] public NodePath VehicleCameraRigPath = "Camera";
	[Export] public NodePath VehicleCameraPath = "Camera/Node3D/Camera3D";
	[Export] public string InteractAction = "interact";
	[Export] public bool DisableControlOnReady = true;

	private Node _vehicleController;
	private Node _currentDriver;
	private Node3D _exitPoint;
	private Node _vehicleCameraRig;
	private Camera3D _vehicleCamera;
	private Camera3D _driverPreviousCamera;
	private bool _exitInputArmed;

	public override void _Ready()
	{
		_vehicleController = GetNodeOrNull(VehicleControllerPath);
		if (_vehicleController == null)
		{
			GD.PushWarning($"vehicle_Interactable: Could not find vehicle controller at path '{VehicleControllerPath}'.");
			return;
		}

		_exitPoint = GetNodeOrNull<Node3D>(ExitPointPath);
		_vehicleCameraRig = GetNodeOrNull(VehicleCameraRigPath);
		_vehicleCamera = GetNodeOrNull<Camera3D>(VehicleCameraPath);

		if (DisableControlOnReady)
		{
			_vehicleController.Set("input_enabled", false);
		}

		SetVehicleCameraActive(false);
	}

	public override void _UnhandledInput(InputEvent @event)
	{
		if (_currentDriver == null)
		{
			return;
		}

		if (@event.IsActionReleased(InteractAction))
		{
			_exitInputArmed = true;
			return;
		}

		if (!@event.IsActionPressed(InteractAction))
		{
			return;
		}

		if (!_exitInputArmed)
		{
			return;
		}

		ExitVehicle(_currentDriver);
		_exitInputArmed = false;
		GD.Print("Vehicle control released (direct exit).");
	}

	// Called by player_Interactor through dynamic dispatch.
	public void interact(Node interactor)
	{
		if (_vehicleController == null)
		{
			return;
		}

		Node player = ResolvePlayerFromInteractor(interactor);
		if (player == null)
		{
			GD.PushWarning("vehicle_Interactable: Could not resolve player from interactor.");
			return;
		}

		if (_currentDriver == player)
		{
			ExitVehicle(player);
			GD.Print("Vehicle control released.");
			return;
		}

		if (_currentDriver != null && _currentDriver != player)
		{
			GD.Print("Vehicle is already occupied.");
			return;
		}

		EnterVehicle(player);
		GD.Print("Vehicle control granted.");
	}

	private void EnterVehicle(Node player)
	{
		_currentDriver = player;
		_exitInputArmed = false;
		GetPlayerState(player)?.EnterVehicle();
		SetControllerInputEnabled(true);
		_driverPreviousCamera = FindCurrentCamera(player);
		SetVehicleCameraActive(true);
		SetPlayerEnabled(player, false);
	}

	private void ExitVehicle(Node player)
	{
			_currentDriver = null;
			GetPlayerState(player)?.ExitVehicle();
			SetControllerInputEnabled(false);
			SetVehicleCameraActive(false);
			if (_driverPreviousCamera != null)
			{
				_driverPreviousCamera.MakeCurrent();
			}
			SetPlayerEnabled(player, true);
			Input.MouseMode = Input.MouseModeEnum.Captured;
			TeleportPlayerToExit(player);
	}

	private void SetControllerInputEnabled(bool enabled)
	{
		_vehicleController.Set("input_enabled", enabled);
	}

	private Node ResolvePlayerFromInteractor(Node interactor)
	{
		if (interactor == null)
		{
			return null;
		}

		Node current = interactor;
		while (current != null)
		{
			if (current is CharacterBody3D)
			{
				return current;
			}
			current = current.GetParent();
		}

		return interactor.GetParent();
	}

	private void SetPlayerEnabled(Node player, bool enabled)
	{
		if (player == null)
		{
			return;
		}

		player.SetPhysicsProcess(enabled);
		player.SetProcessInput(enabled);
		player.SetProcessUnhandledInput(enabled);

		if (player is Node3D playerNode3D)
		{
			playerNode3D.Visible = enabled;
		}
	}

	private void TeleportPlayerToExit(Node player)
	{
		if (_exitPoint == null)
		{
			return;
		}

		if (player is Node3D playerNode3D)
		{
			playerNode3D.GlobalPosition = _exitPoint.GlobalPosition;
		}
	}

	private PlayerState GetPlayerState(Node player)
	{
		if (player == null)
		{
			return null;
		}

		return player.GetNodeOrNull<PlayerState>("PlayerState");
	}

	private void SetVehicleCameraActive(bool active)
	{
		if (_vehicleCameraRig != null)
		{
			_vehicleCameraRig.SetProcessInput(active);
			_vehicleCameraRig.SetProcessUnhandledInput(active);
			_vehicleCameraRig.SetPhysicsProcess(active);
			_vehicleCameraRig.SetProcess(active);
		}

		if (_vehicleCamera != null)
		{
			_vehicleCamera.Current = active;
			if (active)
			{
				_vehicleCamera.MakeCurrent();
			}
		}
	}

	private Camera3D FindCurrentCamera(Node player)
	{
		if (player == null)
		{
			return GetViewport()?.GetCamera3D();
		}

		Camera3D cameraOnPlayer = FindFirstCamera(player);
		if (cameraOnPlayer != null)
		{
			return cameraOnPlayer;
		}

		return GetViewport()?.GetCamera3D();
	}

	private Camera3D FindFirstCamera(Node root)
	{
		if (root is Camera3D camera)
		{
			return camera;
		}

		foreach (Node child in root.GetChildren())
		{
			Camera3D found = FindFirstCamera(child);
			if (found != null)
			{
				return found;
			}
		}

		return null;
	}
}
