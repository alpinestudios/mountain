//RobCode

//
//Place in EntityProps :: enum
//#insert RobEntityProps;
//Adds any custom items into EntityProps struct
//

RobEntityProps :: #string END_EPROPS 
	//Damage over time - Damage Type
	dot;
	is_poison; //Actual Item Poison Effect
	//Effects
	dot_poison;
END_EPROPS

//
//Place in Entity :: struct
//#insert RobEntity;
//Adds any custom items into Entity struct
//

RobEntity :: #string END_ENTITY
	dot_effects: [10]DotEffect;
END_ENTITY



//
//Insert under the EmitterKind :: enum
//#insert RobEmitterKind;
//Stores Custom/ Added Emitter Types
//

RobEmitterKind :: #string END_EMITTER
	poisoned;
	on_fire;
END_EMITTER

//
//Insert under resource.jai - fill_resource_metadata :: inline (res: *ArcResource)
//#insert RobResourceMetaData;
//Stores Resource ID meta data mapping
//

RobResourceMetaData :: #string END_RMETADATA
if res.id ==
	{
		case .poison_bubble;
		res.frame_count = 8;
		res.play_rate = 9;
		case .p_ember;
		res.frame_count = 2;
		res.play_rate = 1;
	}
END_RMETADATA

//
//Insert under resource.jai - ResourceID :: enum
//#insert RobResourceID;
//Stores Resource ID
//

RobResourceID :: #string END_RESOURCEIDS
	poison_bubble;
	p_ember;
END_RESOURCEIDS

//
//Insert in config.jai
//#insert RobConfig;
//Adds any config changes
//Adds Another Layer For forward Particles
//

RobConfig :: #string END_CONFIG
//Layers
Z_ENTITY_PFX ::7;
END_CONFIG


//
//DOT - Damage over time
//The Different Types of Damage over time effects
//
DOTEffects :: enum 
{
	nil;
	poison;
	on_fire;
}


//
//Damage over time Struct
//

DotEffect :: struct
{
	name: DOTEffects= .nil;//name of effect (default value being nil)
	length: float; //how long it lasts (usually a multiple of interval)
	interval: float; //The number of damage ticks
	interval_timer: float;
	damage_amount: int;
	//self: EntityHandle; //The Character with Poison
	inflictor: EntityHandle; //The CHaracter who inflicted Poison
	dot_property: Properties(EntityProps); //make_props(EntityProps.dot, EntityProps.dot_poison)
}

//
//Creates new damage event using information from the damage over time effect
//

attempt_dot_damage :: (dot: DotEffect, en: *Entity) 
{
	//Make a new damage event with the poison effect data
	dmg: DamageEvent;
	dmg.amount = dot.damage_amount;
	dmg.self = handle_from_entity(en);
	dmg.inflictor = dot.inflictor;
	dmg.direction.x = 0.1;
	dmg.damage_props = dot.dot_property;
	en.damage_event = dmg;
}


//
//Place in attempt_damage_entity after damage event
//poison_check(en, from, damage_props);
//Applies a damage over time effect to entity from _other_ entity and checks if damage prop has poison
//

poison_check :: (en : *Entity, from: *Entity, damage_props: Properties(EntityProps))
{
			//Check if item has is_poison
		if has_prop(damage_props, .is_poison)
		{	
			dot : DotEffect ;
			//Name (is now declaring type)
			dot.name = .poison;
			dot.length = 5.0;
			//The interval between damage ticks + setting initial tick of damage timer
			dot.interval = 1.0;
			dot.interval_timer = dot.interval;
			dot.damage_amount = 2;
			//Keep inflictor because you wanna know who killed you
			dot.inflictor = handle_from_entity(from);
			//Used in damage event
			dot.dot_property = make_props(EntityProps.dot, .dot_poison);
			//Add Poison prop .dot_poison - May need to modify (multiple props being added?)
			add_props(*en.props,.dot_poison);
			for d: 0..en.dot_effects.count-1
			{
				if en.dot_effects[d].name == .nil
				{
					//debug_break();
					en.dot_effects[d] = dot;
					break d;
				}
			}
		}
}


//
//DOT Effect Loop
//DOT_loop();
//Place in recieve_damage :: ()
//
DOT_loop :: ()
	{
		//This can totally be optimised
		for * en: g_world.entities
		{
			if has_prop(en.props, .dot_poison)
			{
				//create_emitter(en.pos, .poisoned);
				create_emitter(en.pos, .on_fire);
	
				for d: 0..en.dot_effects.count-1 if (en.dot_effects[d].name != .nil)
				{
					//Timer for the interval of ticks of damage
					if (tick_timer(*(en.dot_effects[d].interval_timer), delta_t_scaled()))
					{	
						//Make the damage happen 
						attempt_dot_damage(en.dot_effects[d], en);
						en.dot_effects[d].interval_timer = en.dot_effects[d].interval;
					}
					//Once length has run out clear the effect
					if tick_timer(*(en.dot_effects[d].length) , delta_t())
					{
						en.dot_effects[d].name = .nil;
	
						for p: 0..en.dot_effects.count-1
						{
							if (en.dot_effects[p].name == .poison) 
							{
								break;
							}
							if (p == en.dot_effects.count-1)
							{
								remove_props(*en.props,.dot_poison);
							}
						}
					}				
				}
			}
		}
	}

	//
//Insert under the if en.emitter == in update_particle_system :: ()
//RobParticles();
//Stores Custom/ Added Particle Effects
//
RobParticles :: (en : *Entity)
{
	if en.emitter ==
	{
		case .poisoned;
		en.marked_for_destroy = true;
		//Put Delay into Entity - For an Emitter
		if tick_on_app_frequency(0.11)
		{
			p := new_particle();
			p.pos = en.pos + xy(random_get_within_range(-5, 5), random_get_within_range(-15, 3));
			p.vel = en.velocity/2 + xy(random_get_within_range(-10, 10), random_get_within_range(6, 20));
			p.col = WHITE;
			p.flags |= ParticleFlags.animate_sprite;
			p.sprite = "poison_bubble";
			//Randomise Layer so not too many on the front of the model
			if random_bool()
			p.z_layer = Z_ENTITY_PFX;
			else
			p.z_layer = Z_ENTITY_VFX;
			p.pivot = .bottom_center;
			p.play_rate = random_get_within_range(2.5, 5);
			//Transform the sprite so that they look less uniform
			p.trs = make_transform(xy(0,0),0,random_get_within_range(0.25, 1));
		}


		case .on_fire;
		//Add Lighting Effect cause Fire- may have to change lighting radius depending on size of original ent
		en.light_radius = 30.0;
		en.light_radius_t = 200 + (sin(cast(float)g_world.time_elapsed * 5) * 5);
		//Time between flickers
		if tick_on_app_frequency(0.45)
		{
			en.light_radius = 30.0 + random_get_within_range(-5, 5);
			en.light_radius_t = 200 + (sin(cast(float)g_world.time_elapsed * 5) * 5);
		}
		en.marked_for_destroy = true;

		//Put Delay into Entity - For an Emitter
		if tick_on_app_frequency(0.05)
		{
			p := new_particle();
			p.pos = en.pos + xy(random_get_within_range(-10, 0), random_get_within_range(-15, 3));
			p.vel = xy(random_get_within_range(-5, 5), random_get_within_range(3, 15));
			p.col = WHITE;
			p.flags |= ParticleFlags.animate_sprite;
			p.sprite = "p_ember";

			p.pivot = .bottom_center;

			//p.z_layer = ifx  random_bool() Z_ENTITY_PFX else Z_ENTITY_VFX;
			if random_bool()
			p.z_layer = Z_ENTITY_PFX;
			else
			p.z_layer = Z_ENTITY_VFX;

			p.play_rate = random_get_within_range(0.8, 2.5);
			p.trs = make_transform(xy(0,0),0,random_get_within_range(0.75, 2));;
		}
	}
}