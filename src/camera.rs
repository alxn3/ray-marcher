use std::f32::consts::PI;

use glam::{EulerRot, Mat4, Quat, Vec3, Vec4};
use instant::Duration;
use winit::event::{ElementState, VirtualKeyCode};

#[derive(Debug)]
pub struct View {
    pub position: Vec3,
    yaw: f32,
    pitch: f32,
    roll: f32,
}

impl View {
    pub fn new(position: Vec3, yaw: f32, pitch: f32, roll: f32) -> Self {
        Self {
            position: position.into(),
            yaw: yaw.into(),
            pitch: pitch.into(),
            roll: roll.into(),
        }
    }

    pub fn calc_matrix(&self) -> Mat4 {
        Mat4::from_rotation_translation(
            Quat::from_euler(EulerRot::YXZ, self.yaw, self.pitch, self.roll),
            self.position,
        )
    }
}

struct MovementValues {
    forward: f32,
    backward: f32,
    left: f32,
    right: f32,
    up: f32,
    down: f32,
}

struct RotationValues {
    yaw: f32,
    pitch: f32,
    clockwise: f32,
    counter_clockwise: f32,
}

#[repr(C)]
#[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
pub struct CameraUniform {
    pub position: Vec4,
    pub view_proj: Mat4,
}
pub struct Camera {
    view: View,
    movement_values: MovementValues,
    rotation_values: RotationValues,
    zoom: f32,
    speed: f32,
    sensitivity: f32,
    pub uniform: CameraUniform,
}

impl Camera {
    pub fn new(view: View, speed: f32, sensitivity: f32) -> Self {
        let position = view.position.extend(1.0).into();
        let view_proj = (view.calc_matrix()).into();

        Self {
            view,
            movement_values: MovementValues {
                forward: 0.0,
                backward: 0.0,
                left: 0.0,
                right: 0.0,
                up: 0.0,
                down: 0.0,
            },
            rotation_values: RotationValues {
                yaw: 0.0,
                pitch: 0.0,
                clockwise: 0.0,
                counter_clockwise: 0.0,
            },
            zoom: 0.0,
            speed,
            sensitivity,
            uniform: CameraUniform {
                position,
                view_proj,
            },
        }
    }

    pub fn process_keyboard(&mut self, key: VirtualKeyCode, state: ElementState) -> bool {
        let amount = if ElementState::Pressed == state {
            1.0
        } else {
            0.0
        };

        match key {
            VirtualKeyCode::W => self.movement_values.forward = amount,
            VirtualKeyCode::S => self.movement_values.backward = amount,
            VirtualKeyCode::A => self.movement_values.left = amount,
            VirtualKeyCode::D => self.movement_values.right = amount,
            VirtualKeyCode::Space => self.movement_values.up = amount,
            VirtualKeyCode::LShift => self.movement_values.down = amount,
            VirtualKeyCode::Q => self.rotation_values.counter_clockwise = amount,
            VirtualKeyCode::E => self.rotation_values.clockwise = amount,
            _ => return false,
        }
        true
    }

    pub fn process_mouse(&mut self, x_offset: f32, y_offset: f32) {
        let x_offset = x_offset * self.sensitivity;
        let y_offset = y_offset * self.sensitivity;

        self.rotation_values.yaw = x_offset;
        self.rotation_values.pitch = -y_offset;
    }

    pub fn process_zoom(&mut self, y_offset: f32) {
        self.zoom = y_offset;
    }

    pub fn look_at(&mut self, target: Vec3) {
        let direction = (target - self.view.position).normalize();
        let pitch = direction.y.atan2(direction.x);
        let yaw = direction.z.atan2(direction.x);
        self.view.yaw = yaw;
        self.view.pitch = pitch;
    }

    pub fn update(&mut self, dt: Duration) {
        let view = self.view.calc_matrix();

        // Update uniform
        self.uniform.position = self.view.position.extend(1.0).into();
        self.uniform.view_proj = (view).into();

        // Movement
        let dt = dt.as_secs_f32();

        let right = Vec3::new(view.x_axis.x, view.x_axis.y, view.x_axis.z) * self.speed * dt;
        let up = Vec3::new(view.y_axis.x, view.y_axis.y, view.y_axis.z) * self.speed * dt;
        let forward = Vec3::new(view.z_axis.x, view.z_axis.y, view.z_axis.z) * self.speed * dt;

        self.view.position += right * self.movement_values.right;
        self.view.position -= right * self.movement_values.left;
        self.view.position -= up * self.movement_values.up;
        self.view.position += up * self.movement_values.down;
        self.view.position += forward * self.movement_values.forward;
        self.view.position -= forward * self.movement_values.backward;

        // Scroll
        self.view.position += forward * self.zoom * self.sensitivity;


        // Rotate
        self.view.yaw += self.rotation_values.yaw * self.sensitivity * dt;
        self.view.pitch += self.rotation_values.pitch * self.sensitivity * dt;
        self.view.roll -= self.rotation_values.counter_clockwise * self.sensitivity * self.speed * dt;
        self.view.roll += self.rotation_values.clockwise * self.sensitivity * self.speed * dt;

        self.rotation_values = RotationValues {
            yaw: 0.0,
            pitch: 0.0,
            ..self.rotation_values
        };

        // Keep rotation values in reasonable Radians
        self.view.yaw = self.view.yaw % (2.0 * PI);
        self.view.pitch = self.view.pitch.clamp(-PI / 2.0, PI / 2.0);
        self.view.roll = self.view.roll % (2.0 * PI);
    }
}
