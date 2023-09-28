# custom blender script for baking NLA tracks out
# the majority of this is courtesy of https://twitter.com/StefDevs

bl_info = {
    "name": "spritebake",
    "blender": (2, 91, 0),
    "category": "spritebake",
}

import bpy
import functools
import bpy.path
import bmesh
from bpy.props import PointerProperty
import numpy as np
import sys
from mathutils import Vector
import math
from math import pi
import os
import shutil
import subprocess


class SpriteBakeContext:
    scene: bpy.types.Scene
    folderPath: ""
    fileNameBase: ""


class SpriteMetaData:
    frameNumber: int
    hand_left_x: float
    hand_left_y: float
    hand_left_rot: float


def Setup():
    spriteBakeContext = SpriteBakeContext()
    spriteBakeContext.scene = bpy.context.scene
    return spriteBakeContext


def Cleanup(spriteBakeContext):
    subprocess.call("C:/rando/dev/mountain/proj/spritesheeter/sheet.exe")
    print("cleanup - we may want to put something here one day")


def SetOutputPathsBase(spriteBakeContext, animationName):
    folderPath = "{outputfolder}{subjectName}\{animName}\\".format(
        outputfolder=spriteBakeContext.scene.spriteBakeOutputPath,
        subjectName=spriteBakeContext.scene.spriteBakeOutputBaseName,
        animName=animationName,
    )
    spriteBakeContext.folderPath = folderPath

    spriteBakeContext.fileNameBase = "{basename}_{anim}".format(
        basename=spriteBakeContext.scene.spriteBakeOutputBaseName,
        anim=animationName,
    )


def SetOutputPaths(spriteBakeContext, frameNumber):
    spriteBakeContext.scene.render.filepath = (
        spriteBakeContext.folderPath
        + str(frameNumber).zfill(3)
        + ".png"
    )
    print(spriteBakeContext.scene.render.filepath)


def ClearOutputFolder(spriteBakeContext):
    path = bpy.path.abspath(spriteBakeContext.folderPath)
    print("clearing " + path)
    try:
        shutil.rmtree(path)
    except:
        print("folderNotFund")
        pass


def RenderFrame(spriteBakeContext):
    bpy.ops.render.render(use_viewport=True, write_still=True)


def BakeNLA(spriteBakeContext, nlatrack):
    # base_model = bpy.data.collections.get("base_model")
    # solo_items = bpy.data.collections.get("solo_items")

    firstFrame = 1000000000000
    lastFrame = -1
    for strip in nlatrack.strips:
        firstFrame = min(firstFrame, strip.frame_start)
        lastFrame = max(lastFrame, strip.frame_end+1)

    nFrames = max(lastFrame - firstFrame, 0)
    if nFrames > 0:
        print(f"{nlatrack.name} {firstFrame} - {lastFrame}, length: {nFrames}")
        SetOutputPathsBase(spriteBakeContext, nlatrack.name)
        ClearOutputFolder(spriteBakeContext)
        # for obj in base_model.objects:
        #     obj.hide_render = False
        # for item in solo_items.objects:
        #     item.hide_render = True

        out_node1 = spriteBakeContext.scene.node_tree.nodes.get("base")
        out_node2 = spriteBakeContext.scene.node_tree.nodes.get("sword")
        out_node1.base_path = spriteBakeContext.folderPath + "/base"
        out_node2.base_path = spriteBakeContext.folderPath + "/sword"

        animationMetaData = []
        i = 0
        frameNumber = 0
        while i < lastFrame:
            # is_keyframe = False;
            # for fcurve in current_object.animation_data.action.fcurves:
            #     for keyframe in fcurve.keyframe_points:
            #         if keyframe.co.x == i:
            #            is_keyframe = True;
            
            SetOutputPaths(spriteBakeContext, frameNumber)
            spriteBakeContext.scene.frame_set(frameNumber)
            RenderFrame(spriteBakeContext)
            animationMetaData.append(
                GetFrameMetaData(spriteBakeContext, frameNumber)
            )
            frameNumber += 1
            i += 1

        SerializeAnimationMetaData(animationMetaData, nlatrack.name, spriteBakeContext)


def GetFrameMetaData(spriteBakeContext, frameNumber):
    frameMetaData = SpriteMetaData()
    frameMetaData.frameNumber = frameNumber
    # record in worldspace, but at serialization-time we use the worldspace data to generate both the center of mass delta and the frame-space center of mass
    # centerOfMass = GetCenterOfMass(spriteBakeContext.scene.spriteBakeSubject_massMesh)
    # frameMetaData.centerOfMass_worldSpace = np.array([centerOfMass[1], centerOfMass[2]])
    # frameMetaData.centerOfMass_frameSpace = (frameMetaData.centerOfMass_worldSpace - frameMin) / frameSize

    camera = bpy.context.scene.camera

    armature = bpy.data.objects['Armature']
    bone = armature.pose.bones.get("grip")

    relative_mat = bone.matrix @ camera.matrix_world.inverted()
    pos = relative_mat.to_translation()

    frameMetaData.hand_left_x = pos.x
    frameMetaData.hand_left_y = pos.y
    # frameMetaData.hand_left_rot =
    return frameMetaData


def SerializeAnimationMetaData(metaData, animName, spriteBakeContext):
    # write metadata to file
    if len(metaData) > 0:
        filePath = (
            bpy.path.abspath(spriteBakeContext.folderPath)
            + spriteBakeContext.fileNameBase
            + ".txt"
        )
        print("writing file " + filePath)
        with open(filePath, "w") as file:
            file.write("[0]\n")
            file.write(
                f"subject_name {spriteBakeContext.scene.spriteBakeOutputBaseName}\n"
            )
            file.write(f"anim_name {animName}\n")
            # file.write(f"ppu {spriteBakeContext.ppu}\n")
            file.write(f"frame_count {len(metaData)}\n")
            for frame in metaData:
                file.write(f"frame {frame.frameNumber}\n")
                file.write(f"hand_x {frame.hand_left_x}\n")
                file.write(f"hand_y {frame.hand_left_y}\n")
    pass


class SPRITEBAKE_OT_BakeCurrentPose(bpy.types.Operator):
    """Bake Current Pose"""

    bl_idname = "spritebake.bakecurrentpose"
    bl_label = "Bake Current Pose"

    def execute(self, context):
        spriteBakeContext = Setup()

        meta = GetFrameMetaData(spriteBakeContext, 0)

        SetOutputPathsBase(spriteBakeContext, "testpose")
        ClearOutputFolder(spriteBakeContext)
        SetOutputPaths(spriteBakeContext, 0)
        RenderFrame(spriteBakeContext)
        Cleanup(spriteBakeContext)
        return {"FINISHED"}


class SPRITEBAKE_OT_BakeAllAnimations(bpy.types.Operator):
    """Bake All NLAs"""

    bl_idname = "spritebake.bakeallanimations"
    bl_label = "Bake All Anims"

    def execute(self, context):
        spriteBakeContext = Setup()
        for (
            nlatrack
        ) in spriteBakeContext.scene.spriteBakeSubject_rig.animation_data.nla_tracks:
            nlatrack.is_solo = True
            BakeNLA(spriteBakeContext, nlatrack)
            nlatrack.is_solo = False
        Cleanup(spriteBakeContext)
        return {"FINISHED"}


class SPRITEBAKE_OT_BakeCurrentNLA(bpy.types.Operator):
    """Bake Current NLA"""

    bl_idname = "spritebake.bakecurrentnla"
    bl_label = "Bake Current NLA"

    def execute(self, context):
        spriteBakeContext = Setup()
        for (
            nlatrack
        ) in spriteBakeContext.scene.spriteBakeSubject_rig.animation_data.nla_tracks:
            if nlatrack.is_solo:
                BakeNLA(spriteBakeContext, nlatrack)
        Cleanup(spriteBakeContext)
        return {"FINISHED"}


class SpriteBakePanel(bpy.types.Panel):
    """Pathgen control panel"""

    bl_label = "SpriteBake Panel"
    bl_idname = "OBJECT_PT_spritebake"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "spritebake"

    def draw(self, context):
        layout = self.layout
        row = layout.row()
        row.prop(context.scene, "spriteBakeSubject_rig")
        row = layout.row()
        row.prop(context.scene, "spriteBakeOutputPath")
        row = layout.row()
        row.prop(context.scene, "spriteBakeOutputBaseName")
        row = layout.row()
        row.operator("spritebake.bakecurrentpose")
        row = layout.row()
        row.operator("spritebake.bakecurrentnla")
        row = layout.row()
        row.operator("spritebake.bakeallanimations")


classes = (
    SPRITEBAKE_OT_BakeCurrentPose,
    SPRITEBAKE_OT_BakeAllAnimations,
    SPRITEBAKE_OT_BakeCurrentNLA,
    SpriteBakePanel,
)


def register():
    bpy.types.Scene.spriteBakeSubject_rig = PointerProperty(
        type=bpy.types.Object, name="rig"
    )
    bpy.types.Scene.spriteBakeOutputPath = bpy.props.StringProperty(
        subtype="FILE_PATH", name="output folder"
    )
    bpy.types.Scene.spriteBakeOutputBaseName = bpy.props.StringProperty(
        name="subject name"
    )
    for cl in classes:
        bpy.utils.register_class(cl)


def unregister():
    for cl in classes:
        bpy.utils.unregister_class(cl)


if __name__ == "__main__":
    register()
